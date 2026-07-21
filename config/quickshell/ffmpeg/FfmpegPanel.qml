// FFmpeg panel — select a video file via Qt.labs.platform.FileDialog
// (routes to the XDG FileChooser portal on Wayland) and run common
// ffmpeg operations: container conversion, audio extraction, no-re-encode
// trimming, resizing, compression, GIF creation, and audio/video merging.
//
// Outputs land next to the input file, named
// <basename>_<op>_<HHMMSS>.<ext> so repeated runs never collide.

pragma ComponentBehavior: Bound

import "../theme"
import "../components"
import "../util"
import "../notifications"
import QtQuick
import Qt.labs.platform as Platform
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications

Panel {
    id: root
    title: "FFmpeg"
    sections: [
        { name: "File" },
        { name: "Convert" },
        { name: "Extract Audio" },
        { name: "Trim" },
        { name: "Resize" },
        { name: "Compress" },
        { name: "GIF" },
        { name: "Merge" },
        { name: "Job" }
    ]

    // --- Named section indices ---
    readonly property int secFile: 0
    readonly property int secConvert: 1
    readonly property int secExtract: 2
    readonly property int secTrim: 3
    readonly property int secResize: 4
    readonly property int secCompress: 5
    readonly property int secGif: 6
    readonly property int secMerge: 7
    readonly property int secJob: 8

    // ================= Job runner =================

    JobRunner {
        id: jobRunner
        onFinished: (label, output) => {
            NotifDaemon.notify("FFmpeg: " + label + " finished",
                root.tildify(output), NotificationUrgency.Normal)
        }
        onFailed: (label, error, exitCode) => {
            NotifDaemon.notify("FFmpeg: " + label + " failed (exit " + exitCode + ")",
                error.slice(0, 300), NotificationUrgency.Critical)
        }
        onBusy: {
            NotifDaemon.notify("FFmpeg is busy",
                "A job is already running — cancel it in the Job section first.",
                NotificationUrgency.Normal)
        }
    }

    // ================= File pickers =================

    Platform.FileDialog {
        id: videoPicker
        title: "Open Video File"
        fileMode: Platform.FileDialog.OpenFile
        nameFilters: ["Video files (*.mp4 *.mkv *.webm *.mov *.avi *.ts *.mts *.wmv *.flv *.m4v *.mpg *.mpeg *.3gp)", "All files (*)"]
        onAccepted: root.pickFile(Paths.urlToLocalFile(videoPicker.file))
        onRejected: {}
    }

    Platform.FileDialog {
        id: audioPicker
        title: "Pick Audio Track"
        fileMode: Platform.FileDialog.OpenFile
        nameFilters: ["Audio & video files (*.mp3 *.m4a *.aac *.flac *.wav *.opus *.ogg *.wma *.mka *.mp4 *.mkv *.mov)", "All files (*)"]
        onAccepted: root.audioPath = Paths.urlToLocalFile(audioPicker.file)
        onRejected: {}
    }

    // ================= Input metadata =================

    property string inputPath: ""
    readonly property bool hasInput: inputPath !== ""
    property real inputDuration: 0
    property string inputInfo: ""
    property string inputAudioCodec: ""

    function pickFile(path) {
        root.inputPath = path
        root.inputInfo = "probing…"
        root.inputDuration = 0
        root.inputAudioCodec = ""
        probeProc.command = ["ffprobe", "-v", "error", "-print_format", "json",
                             "-show_format", "-show_streams", path]
        probeProc.running = true
    }

    Process {
        id: probeProc
        stdout: StdioCollector { id: probeOut }
        onExited: (exitCode) => {
            if (exitCode !== 0) { root.inputInfo = "unreadable (ffprobe failed)"; return }
            var j
            try { j = JSON.parse(probeOut.text) } catch (e) {
                root.inputInfo = "unreadable (bad ffprobe output)"; return
            }
            var v = null, a = null
            var streams = j.streams || []
            for (var i = 0; i < streams.length; i++) {
                if (!v && streams[i].codec_type === "video") v = streams[i]
                if (!a && streams[i].codec_type === "audio") a = streams[i]
            }
            root.inputDuration = parseFloat(j.format && j.format.duration) || 0
            root.inputAudioCodec = a ? (a.codec_name || "") : ""
            var parts = []
            if (v) parts.push(v.width + "x" + v.height)
            parts.push((v ? v.codec_name : "no video") + "/" + (a ? a.codec_name : "no audio"))
            if (root.inputDuration > 0) parts.push(root.fmtTime(root.inputDuration))
            var bytes = parseInt(j.format && j.format.size, 10)
            if (!isNaN(bytes)) parts.push((bytes / 1048576).toFixed(1) + " MB")
            root.inputInfo = parts.join(" · ")
            root.trimStartSec = 0
            root.trimEndSec = root.inputDuration
        }
    }

    // ================= Output naming =================

    function baseName(p) { return p.slice(p.lastIndexOf("/") + 1) }

    function parentDir(p) {
        var i = p.lastIndexOf("/")
        return i > 0 ? p.slice(0, i) : "/"
    }

    function tildify(p) {
        return p.startsWith(Paths.home) ? "~" + p.slice(Paths.home.length) : p
    }

    function inputExt() {
        var dot = root.inputPath.lastIndexOf(".")
        return dot > root.inputPath.lastIndexOf("/") ? root.inputPath.slice(dot + 1) : "mkv"
    }

    function outPath(tag, ext) {
        var d = new Date()
        var stamp = FormatUtil.zeroPad(d.getHours()) + FormatUtil.zeroPad(d.getMinutes())
                  + FormatUtil.zeroPad(d.getSeconds())
        var dir = root.parentDir(root.inputPath)
        var base = root.baseName(root.inputPath)
        var dot = base.lastIndexOf(".")
        if (dot > 0) base = base.slice(0, dot)
        return dir + "/" + base + "_" + tag + "_" + stamp + "." + ext
    }

    // ================= Time helpers =================

    function parseTime(t) {
        var parts = t.trim().split(":")
        if (parts.length < 1 || parts.length > 3) return NaN
        var s = 0
        for (var i = 0; i < parts.length; i++) {
            if (parts[i] === "" || isNaN(Number(parts[i]))) return NaN
            s = s * 60 + Number(parts[i])
        }
        return s
    }

    function fmtTime(sec) {
        var s = Math.round(Math.max(0, sec))
        var h = Math.floor(s / 3600)
        var m = Math.floor((s % 3600) / 60)
        var ss = s % 60
        return h > 0 ? h + ":" + FormatUtil.zeroPad(m) + ":" + FormatUtil.zeroPad(ss)
                     : m + ":" + FormatUtil.zeroPad(ss)
    }

    // ================= Operations =================

    readonly property var convertOps: [
        { name: "MP4 (remux)", desc: "no re-encode; fails if codecs don't fit mp4",
          tag: "mp4", ext: "mp4", args: ["-c", "copy"] },
        { name: "MP4 (H.264 / AAC)", desc: "re-encode, plays everywhere",
          tag: "mp4", ext: "mp4",
          args: ["-c:v", "libx264", "-crf", "20", "-preset", "veryfast", "-c:a", "aac", "-b:a", "192k"] },
        { name: "MKV (remux)", desc: "no re-encode; mkv holds any codec",
          tag: "mkv", ext: "mkv", args: ["-c", "copy"] },
        { name: "MOV (remux)", desc: "no re-encode",
          tag: "mov", ext: "mov", args: ["-c", "copy"] },
        { name: "WebM (VP9 / Opus)", desc: "re-encode, slow but small",
          tag: "webm", ext: "webm",
          args: ["-c:v", "libvpx-vp9", "-crf", "32", "-b:v", "0", "-c:a", "libopus"] }
    ]

    function runConvert(idx) {
        var op = root.convertOps[idx]
        if (!op || !root.hasInput) return
        var out = root.outPath(op.tag, op.ext)
        if (jobRunner.start("convert to " + op.ext.toUpperCase(),
            ["-i", root.inputPath].concat(op.args).concat([out]),
            out, root.inputDuration)) root.selSection = root.secJob
    }

    readonly property var extractOps: [
        { name: "Original codec", desc: "stream copy, instant", copy: true },
        { name: "MP3", desc: "V2, ~190 kbps", ext: "mp3", args: ["-c:a", "libmp3lame", "-q:a", "2"] },
        { name: "AAC (m4a)", desc: "192 kbps", ext: "m4a", args: ["-c:a", "aac", "-b:a", "192k"] },
        { name: "Opus", desc: "128 kbps", ext: "opus", args: ["-c:a", "libopus", "-b:a", "128k"] },
        { name: "FLAC", desc: "lossless", ext: "flac", args: ["-c:a", "flac"] },
        { name: "WAV", desc: "PCM, huge", ext: "wav", args: ["-c:a", "pcm_s16le"] }
    ]

    function audioCopyExt() {
        var map = { aac: "m4a", alac: "m4a", mp3: "mp3", opus: "opus",
                    vorbis: "ogg", flac: "flac" }
        return map[root.inputAudioCodec] || "mka"
    }

    function runExtract(idx) {
        var op = root.extractOps[idx]
        if (!op || !root.hasInput) return
        if (root.inputAudioCodec === "") {
            NotifDaemon.notify("FFmpeg", "The selected file has no audio track.",
                NotificationUrgency.Normal)
            return
        }
        var ext = op.copy ? root.audioCopyExt() : op.ext
        var args = op.copy ? ["-c:a", "copy"] : op.args
        var out = root.outPath("audio", ext)
        if (jobRunner.start("extract audio",
            ["-i", root.inputPath, "-vn"].concat(args).concat([out]),
            out, root.inputDuration)) root.selSection = root.secJob
    }

    // --- Trim ---
    property real trimStartSec: 0
    property real trimEndSec: 0

    function runTrim() {
        if (!root.hasInput) return
        if (root.trimEndSec <= root.trimStartSec) {
            NotifDaemon.notify("FFmpeg", "Trim end must be after the start.",
                NotificationUrgency.Normal)
            return
        }
        var out = root.outPath("trim", root.inputExt())
        // -ss/-to before -i: seeks the demuxer (fast, required for clean
        // stream copy); avoid_negative_ts rebases timestamps to 0.
        if (jobRunner.start("trim",
            ["-ss", String(root.trimStartSec), "-to", String(root.trimEndSec),
             "-i", root.inputPath, "-c", "copy", "-avoid_negative_ts", "make_zero", out],
            out, root.trimEndSec - root.trimStartSec)) root.selSection = root.secJob
    }

    // --- Resize ---
    readonly property var resizeHeights: [2160, 1440, 1080, 720, 480, 360]

    function runScale(vf, tag) {
        var out = root.outPath(tag, "mp4")
        if (jobRunner.start("resize",
            ["-i", root.inputPath, "-vf", vf,
             "-c:v", "libx264", "-crf", "20", "-preset", "veryfast",
             "-c:a", "aac", "-b:a", "192k", out],
            out, root.inputDuration)) root.selSection = root.secJob
    }

    function runResize(idx) {
        if (!root.hasInput) return
        if (idx < root.resizeHeights.length) {
            var h = root.resizeHeights[idx]
            // -2: keep aspect ratio; forces even width that libx264 requires.
            root.runScale("scale=-2:" + h, h + "p")
        } else {
            root.editing = "resize"
        }
    }

    function commitResize(text) {
        root.endEdit()
        var t = text.trim().toLowerCase()
        var m = t.match(/^(\d+)\s*[x:]\s*(\d+)$/)
        if (m) root.runScale("scale=" + m[1] + ":" + m[2], m[1] + "x" + m[2])
        else if (/^\d+$/.test(t)) root.runScale("scale=-2:" + t, t + "p")
        else NotifDaemon.notify("FFmpeg", "Enter a height (720) or WxH (1280x720).",
                 NotificationUrgency.Normal)
    }

    // --- Compress ---
    readonly property var compressOps: [
        { name: "Light (CRF 23)", desc: "barely visible loss", crf: 23, scale: "" },
        { name: "Medium (CRF 28)", desc: "good quality, much smaller", crf: 28, scale: "" },
        { name: "Strong (CRF 32)", desc: "visible loss, small", crf: 32, scale: "" },
        { name: "Smallest (CRF 32 + 720p)", desc: "also downscales to 720p", crf: 32, scale: "scale=-2:720" }
    ]

    function runCompress(idx) {
        var op = root.compressOps[idx]
        if (!op || !root.hasInput) return
        var args = ["-i", root.inputPath]
        if (op.scale !== "") args = args.concat(["-vf", op.scale])
        var out = root.outPath("crf" + op.crf, "mp4")
        if (jobRunner.start("compress",
            args.concat(["-c:v", "libx264", "-crf", String(op.crf), "-preset", "medium",
                         "-c:a", "aac", "-b:a", "128k", out]),
            out, root.inputDuration)) root.selSection = root.secJob
    }

    // --- GIF ---
    readonly property var gifFpsOpts: [10, 12, 15, 20, 25]
    readonly property var gifWidthOpts: [320, 480, 640, 800, "source"]
    property int gifFpsIdx: 2
    property int gifWidthIdx: 1

    function runGif() {
        if (!root.hasInput) return
        var f = "fps=" + root.gifFpsOpts[root.gifFpsIdx]
        var w = root.gifWidthOpts[root.gifWidthIdx]
        if (w !== "source") f += ",scale=" + w + ":-1:flags=lanczos"
        f += ",split[s0][s1];[s0]palettegen[p];[s1][p]paletteuse"
        var out = root.outPath("gif", "gif")
        if (jobRunner.start("GIF",
            ["-i", root.inputPath, "-vf", f, "-loop", "0", out],
            out, root.inputDuration)) root.selSection = root.secJob
    }

    // --- Merge ---
    property string audioPath: ""

    function runMerge(mp4) {
        if (!root.hasInput) return
        if (root.audioPath === "") {
            audioPicker.open()
            return
        }
        var codec = mp4 ? ["-c:v", "copy", "-c:a", "aac", "-b:a", "192k"]
                        : ["-c", "copy"]
        var ext = mp4 ? "mp4" : "mkv"
        var out = root.outPath("merged", ext)
        // -shortest: end at the shorter track; avoids frozen last frame
        // hanging under leftover audio (or silent video past audio end).
        if (jobRunner.start("merge",
            ["-i", root.inputPath, "-i", root.audioPath,
             "-map", "0:v:0", "-map", "1:a:0"].concat(codec)
             .concat(["-shortest", out]),
            out, root.inputDuration)) root.selSection = root.secJob
    }

    // ================= Panel navigation =================

    currentModelLength: function() {
        switch (root.selSection) {
        case root.secFile:     return 1  // Browse button always present
        case root.secConvert:  return root.hasInput ? root.convertOps.length : 0
        case root.secExtract:  return root.hasInput ? root.extractOps.length : 0
        case root.secTrim:     return root.hasInput ? 3 : 0
        case root.secResize:   return root.hasInput ? root.resizeHeights.length + 1 : 0
        case root.secCompress: return root.hasInput ? root.compressOps.length : 0
        case root.secGif:      return root.hasInput ? 3 : 0
        case root.secMerge:    return root.hasInput ? 3 : 0
        case root.secJob:      return jobRunner.running ? 1 : 0
        default: return 0
        }
    }

    // --- Per-row dropdown state (every panel row except inline-edit
    // EditRows opens a dropdown of one or more actions on click rather
    // than direct-activating). State + close/toggle/trigger + keyboard
    // nav all live on the shared DropdownState; the panel supplies
    // rowActions(idx) (per-section action list) and triggerAction(idx,
    // actIdx) (per-section perform).
    //
    // EditRows keep their inline-text edit mode reached via their own
    // dropdown's single "Edit" action (see EditRow below).
    DropdownState {
        id: dropdown
        selectRow: function(idx) { root.selectRow(idx) }
        rowActions: function(idx) { return root.rowActions(idx) }
        triggerAction: function(idx, actIdx) { root.doRowAction(idx, actIdx) }
    }

    // Aliases preserved so existing delegate bindings to
    // `root.expandedRowIdx` / `root.selRowAction` and the close/toggle/
    // trigger helpers keep working.
    property int expandedRowIdx: dropdown.expandedRowIdx
    property int selRowAction: dropdown.selRowAction
    function closeRowDropdown() { dropdown.close() }
    function toggleRowDropdown(idx) { dropdown.toggle(idx) }
    function triggerRowAction(idx, actIdx) { dropdown.trigger(idx, actIdx) }

    // Action list for the row at idx in the current section.
    // Single-action rows carry one item (the run verb); cycle-style
    // rows (gifFpsIdx / gifWidthIdx) list every option so the dropdown
    // replaces the click-to-cycle UX with click-to-pick; the audio-row
    // offers Browse / Clear.
    function rowActions(idx) {
        switch (root.selSection) {
        case root.secFile:
            return [{ name: "Browse for video file…", action: "browse" }]
        case root.secConvert:
            if (!root.hasInput) return []
            return [{ name: "Convert to " + root.convertOps[idx].ext, action: "run-convert" }]
        case root.secExtract:
            if (!root.hasInput) return []
            var exOp = root.extractOps[idx]
            return [{ name: "Extract ." + (exOp.copy ? root.audioCopyExt() : exOp.ext),
                      action: "run-extract" }]
        case root.secTrim:
            if (!root.hasInput) return []
            if (idx === 0) return [{ name: "Edit start time", action: "edit-start" }]
            if (idx === 1) return [{ name: "Edit end time",   action: "edit-end" }]
            return [{ name: "Run trim", action: "run-trim" }]
        case root.secResize:
            if (!root.hasInput) return []
            if (idx < root.resizeHeights.length)
                return [{ name: "Resize to " + root.resizeHeights[idx] + "p", action: "run-resize" }]
            return [{ name: "Edit custom size", action: "edit-resize" }]
        case root.secCompress:
            if (!root.hasInput) return []
            return [{ name: "Compress (CRF " + root.compressOps[idx].crf + ")", action: "run-compress" }]
        case root.secGif:
            if (!root.hasInput) return []
            if (idx === 0) {
                var fpsOpts = []
                for (var i = 0; i < root.gifFpsOpts.length; i++)
                    fpsOpts.push({ name: root.gifFpsOpts[i] + " fps", action: "set-fps", value: i })
                return fpsOpts
            }
            if (idx === 1) {
                var wOpts = []
                for (var j = 0; j < root.gifWidthOpts.length; j++) {
                    var w = root.gifWidthOpts[j]
                    wOpts.push({ name: w === "source" ? "source width" : w + " px", action: "set-width", value: j })
                }
                return wOpts
            }
            return [{ name: "Create GIF", action: "run-gif" }]
        case root.secMerge:
            if (!root.hasInput) return []
            if (idx === 0) return [{ name: "Browse for audio…", action: "browse-audio" },
                                   { name: "Clear audio track", action: "clear-audio" }]
            if (idx === 1) return [{ name: "Merge → MKV", action: "merge-mkv" }]
            return [{ name: "Merge → MP4", action: "merge-mp4" }]
        case root.secJob:
            if (idx === 0) return [{ name: "Cancel running job", action: "cancel-job" }]
            return []
        }
        return []
    }

    function doRowAction(idx, actIdx) {
        var acts = root.rowActions(idx)
        var act = acts[actIdx]
        if (!act) return
        switch (act.action) {
        case "browse":       videoPicker.open(); break
        case "run-convert":  root.runConvert(idx); break
        case "run-extract":  root.runExtract(idx); break
        case "edit-start":   root.editing = "start"; break
        case "edit-end":     root.editing = "end"; break
        case "run-trim":     root.runTrim(); break
        case "run-resize":   root.runResize(idx); break
        case "edit-resize":  root.editing = "resize"; break
        case "run-compress": root.runCompress(idx); break
        case "set-fps":      root.gifFpsIdx = act.value; break
        case "set-width":    root.gifWidthIdx = act.value; break
        case "run-gif":      root.runGif(); break
        case "browse-audio": audioPicker.open(); break
        case "clear-audio":  root.audioPath = ""; break
        case "merge-mkv":    root.runMerge(false); break
        case "merge-mp4":    root.runMerge(true); break
        case "cancel-job":   jobRunner.cancel(); break
        }
    }

    onDeviceActivated: function(idx) {
        // Section rows are dropdown-driven; onKeyPressed intercepts Enter
        // to open the dropdown. Kept as a no-op so PanelNav's contract
        // is satisfied for keyboard Enter.
    }

    // Escape cancels an inline edit before Panel's default handler
    // exits the section or closes the panel; also drives the dropdown
    // nav (Tab/Enter opens, J/K walks actions, Enter triggers).
    onKeyPressed: function(event) {
        if (root.editing !== "" && event.key === Qt.Key_Escape) {
            root.endEdit()
            event.accepted = true
            return
        }
        if (root.inSection) {
            // DropdownState.handleKey covers all sections in this panel
            // (File/Convert/Extract/Trim/Resize/Compress/GIF/Merge/Job):
            // open on Enter/Tab, navigate with J/K, trigger on Enter/
            // Tab while open, close on Backtab/Escape, Shift+Tab
            // climb-out preserved.
            if (dropdown.handleKey(event, root.selDevice)) return
        }
    }

    onVisibleChanged: if (!visible) { root.editing = ""; root.closeRowDropdown() }
    onSelSectionChanged: { root.editing = ""; root.closeRowDropdown() }

    // Variable-height scroll: open dropdowns add to row height.
    onSelRowActionChanged: Qt.callLater(root.scrollToSelection)
    onExpandedRowIdxChanged: Qt.callLater(root.scrollToSelection)

    function scrollToSelection() {
        if (!root.inSection) return
        // Drop into the base Panel.qml fixed-stride math; dropdown
        // expansion adds a small scroll tail that the regular keep-
        // selection-visible handler absorbs. Rows are uniform rowHeight
        // + colSpacing strands (no EmptyLabels grow the model index),
        // so the straight math stays correct on the row body itself.
        var y = root.headerHeight + root.colSpacing
              + root.selDevice * (root.rowHeight + root.colSpacing)
        root.scrollToVisible(y, root.rowHeight)
        if (root.expandedRowIdx === root.selDevice && root.selRowAction >= 0) {
            var actY = y + root.rowHeight
                      + root.selRowAction * Theme.searchRowHeight
            root.scrollToVisible(actY, Theme.searchRowHeight)
        }
    }

    // Inline-edit state for Trim times and the custom Resize row.
    property string editing: ""
    onSectionChanged: function(idx) { root.editing = "" }
    onShown: root.editing = ""

    function deferredFocus() { Qt.callLater(root.forceFocus) }
    function endEdit() { root.editing = ""; root.deferredFocus() }

    function commitTrim(which, text) {
        var s = root.parseTime(text)
        root.endEdit()
        if (isNaN(s) || s < 0) {
            NotifDaemon.notify("FFmpeg", "Enter a time as seconds, m:ss, or h:mm:ss.",
                NotificationUrgency.Normal)
            return
        }
        if (which === "start") root.trimStartSec = s
        else root.trimEndSec = s
    }

    // ================= Shared row components =================

    component OpRow: DropdownRow {
        id: opRow
        required property var modelData
        required property int index
        property string name: ""
        property string desc: ""
        width: parent.width
        rowHeight: root.rowHeight

        // Default slot lands in DropdownRow's headerItem; ThemeText
        // anchors are relative to that Item (height = rowHeight).

        ThemeText {
            id: opName
            text: opRow.name
            anchors { left: parent.left; leftMargin: Theme.margin; verticalCenter: parent.verticalCenter }
            elide: Text.ElideRight
            width: Math.min(implicitWidth, parent.width * 0.55)
        }

        ThemeText {
            text: opRow.desc
            anchors { right: parent.right; rightMargin: Theme.margin; verticalCenter: parent.verticalCenter }
            color: Qt.alpha(Colors.foreground, Theme.alphaDim)
            elide: Text.ElideRight
            width: Math.min(implicitWidth, parent.width - opName.width - 3 * Theme.margin)
            horizontalAlignment: Text.AlignRight
        }
    }

    component EditRow: DropdownRow {
        id: editRow
        property string name: ""
        property string value: ""
        property string editKey: ""
        signal committed(string text)

        readonly property bool editingThis: root.editing === editKey
        width: parent.width
        rowHeight: root.rowHeight

        ThemeText {
            text: editRow.name
            anchors { left: parent.left; leftMargin: Theme.margin; verticalCenter: parent.verticalCenter }
        }

        ThemeText {
            visible: !editRow.editingThis
            text: editRow.value
            anchors { right: parent.right; rightMargin: Theme.margin; verticalCenter: parent.verticalCenter }
        }

        TextInput {
            visible: editRow.editingThis
            anchors {
                right: parent.right; rightMargin: Theme.margin
                verticalCenter: parent.verticalCenter
            }
            width: parent.width * 0.4
            horizontalAlignment: TextInput.AlignRight
            color: Colors.foreground
            font.pixelSize: Theme.fontPixelSize
            font.family: Theme.fontFamily
            onAccepted: editRow.committed(text)
            onVisibleChanged: {
                text = editRow.value
                if (visible) { forceActiveFocus(); selectAll() }
            }
            Keys.onPressed: (event) => {
                if (event.key === Qt.Key_Escape) {
                    root.endEdit(); event.accepted = true
                }
            }
        }
    }

    component NoFileLabel: EmptyLabel {
        visible: !root.hasInput
        text: "Select a video file first (File section)"
    }

    // ================= File section =================

    Column {
        id: fileColumn
        width: parent.width
        spacing: root.colSpacing
        visible: root.selSection === root.secFile

        // Selected-file info block.
        Item {
            width: parent.width
            height: root.rowHeight

            ThemeText {
                text: root.hasInput ? root.baseName(root.inputPath) : "No file selected"
                anchors { left: parent.left; leftMargin: Theme.margin; right: parent.right; rightMargin: Theme.margin }
                y: 4
                elide: Text.ElideRight
                color: root.hasInput ? Colors.foreground : Qt.alpha(Colors.foreground, Theme.alphaDim)
            }

            ThemeText {
                text: root.inputInfo
                anchors { left: parent.left; leftMargin: Theme.margin; right: parent.right; rightMargin: Theme.margin; top: parent.top; topMargin: 24 }
                color: Qt.alpha(Colors.foreground, Theme.alphaBackground)
                elide: Text.ElideRight
            }
        }

        DropdownRow {
            width: parent.width
            rowHeight: root.rowHeight
            isSelected: root.inSection && 0 === root.selDevice
            isExpanded: root.expandedRowIdx === 0
            selActionIndex: root.expandedRowIdx === 0 ? root.selRowAction : -1
            actions: root.rowActions(0)

            onToggled: root.toggleRowDropdown(0)
            onActionTriggered: (idx) => root.triggerRowAction(0, idx)

            ThemeText {
                text: root.hasInput ? "Browse for another file…" : "Browse for video file…"
                anchors { left: parent.left; leftMargin: Theme.margin; verticalCenter: parent.verticalCenter }
            }
        }
    }

    // ================= Convert =================

    Column {
        id: convertColumn
        width: parent.width
        spacing: root.colSpacing
        visible: root.selSection === root.secConvert

        NoFileLabel {}

        Repeater {
            model: root.hasInput ? root.convertOps : []
            delegate: OpRow {
                name: modelData.name; desc: modelData.desc
                isSelected: root.inSection && index === root.selDevice
                isExpanded: root.expandedRowIdx === index
                selActionIndex: root.expandedRowIdx === index ? root.selRowAction : -1
                actions: root.rowActions(index)
                onToggled: root.toggleRowDropdown(index)
                onActionTriggered: (idx) => root.triggerRowAction(index, idx)
            }
        }
    }

    // ================= Extract Audio =================

    Column {
        id: extractColumn
        width: parent.width
        spacing: root.colSpacing
        visible: root.selSection === root.secExtract

        NoFileLabel {}

        EmptyLabel {
            visible: root.hasInput && root.inputAudioCodec === ""
            text: "The selected file has no audio track"
        }

        Repeater {
            model: root.hasInput && root.inputAudioCodec !== "" ? root.extractOps : []
            delegate: OpRow {
                name: modelData.name
                desc: modelData.copy ? "stream copy → ." + root.audioCopyExt() : modelData.desc
                isSelected: root.inSection && index === root.selDevice
                isExpanded: root.expandedRowIdx === index
                selActionIndex: root.expandedRowIdx === index ? root.selRowAction : -1
                actions: root.rowActions(index)
                onToggled: root.toggleRowDropdown(index)
                onActionTriggered: (idx) => root.triggerRowAction(index, idx)
            }
        }
    }

    // ================= Trim =================

    Column {
        id: trimColumn
        width: parent.width
        spacing: root.colSpacing
        visible: root.selSection === root.secTrim

        NoFileLabel {}

        EditRow {
            visible: root.hasInput
            name: "Start"; value: root.fmtTime(root.trimStartSec); editKey: "start"
            isSelected: root.inSection && 0 === root.selDevice
            isExpanded: root.expandedRowIdx === 0
            selActionIndex: root.expandedRowIdx === 0 ? root.selRowAction : -1
            actions: root.rowActions(0)
            onToggled: root.toggleRowDropdown(0)
            onActionTriggered: (idx) => root.triggerRowAction(0, idx)
            onCommitted: text => root.commitTrim("start", text)
        }

        EditRow {
            visible: root.hasInput
            name: "End"; value: root.fmtTime(root.trimEndSec); editKey: "end"
            isSelected: root.inSection && 1 === root.selDevice
            isExpanded: root.expandedRowIdx === 1
            selActionIndex: root.expandedRowIdx === 1 ? root.selRowAction : -1
            actions: root.rowActions(1)
            onToggled: root.toggleRowDropdown(1)
            onActionTriggered: (idx) => root.triggerRowAction(1, idx)
            onCommitted: text => root.commitTrim("end", text)
        }

        OpRow {
            index: -1
            modelData: null
            visible: root.hasInput
            name: "Cut " + root.fmtTime(root.trimStartSec) + " – " + root.fmtTime(root.trimEndSec)
            desc: "stream copy — instant, cuts on keyframes"
            isSelected: root.inSection && 2 === root.selDevice
            isExpanded: root.expandedRowIdx === 2
            selActionIndex: root.expandedRowIdx === 2 ? root.selRowAction : -1
            actions: root.rowActions(2)
            onToggled: root.toggleRowDropdown(2)
            onActionTriggered: (idx) => root.triggerRowAction(2, idx)
        }
    }

    // ================= Resize =================

    Column {
        id: resizeColumn
        width: parent.width
        spacing: root.colSpacing
        visible: root.selSection === root.secResize

        NoFileLabel {}

        Repeater {
            model: root.hasInput ? root.resizeHeights : []
            delegate: OpRow {
                name: modelData + "p"; desc: "H.264/AAC mp4, keeps aspect"
                isSelected: root.inSection && index === root.selDevice
                isExpanded: root.expandedRowIdx === index
                selActionIndex: root.expandedRowIdx === index ? root.selRowAction : -1
                actions: root.rowActions(index)
                onToggled: root.toggleRowDropdown(index)
                onActionTriggered: (idx) => root.triggerRowAction(index, idx)
            }
        }

        EditRow {
            visible: root.hasInput
            name: "Custom…"; value: root.editing === "resize" ? "" : "height or WxH"
            editKey: "resize"
            isSelected: root.inSection && root.resizeHeights.length === root.selDevice
            isExpanded: root.expandedRowIdx === root.resizeHeights.length
            selActionIndex: root.expandedRowIdx === root.resizeHeights.length ? root.selRowAction : -1
            actions: root.rowActions(root.resizeHeights.length)
            onToggled: root.toggleRowDropdown(root.resizeHeights.length)
            onActionTriggered: (idx) => root.triggerRowAction(root.resizeHeights.length, idx)
            onCommitted: text => root.commitResize(text)
        }
    }

    // ================= Compress =================

    Column {
        id: compressColumn
        width: parent.width
        spacing: root.colSpacing
        visible: root.selSection === root.secCompress

        NoFileLabel {}

        Repeater {
            model: root.hasInput ? root.compressOps : []
            delegate: OpRow {
                name: modelData.name; desc: modelData.desc
                isSelected: root.inSection && index === root.selDevice
                isExpanded: root.expandedRowIdx === index
                selActionIndex: root.expandedRowIdx === index ? root.selRowAction : -1
                actions: root.rowActions(index)
                onToggled: root.toggleRowDropdown(index)
                onActionTriggered: (idx) => root.triggerRowAction(index, idx)
            }
        }
    }

    // ================= GIF =================

    Column {
        id: gifColumn
        width: parent.width
        spacing: root.colSpacing
        visible: root.selSection === root.secGif

        NoFileLabel {}

        OpRow {
            index: -1
            modelData: null
            visible: root.hasInput
            name: "Frame rate: " + root.gifFpsOpts[root.gifFpsIdx] + " fps"
            desc: "Click to pick"
            isSelected: root.inSection && 0 === root.selDevice
            isExpanded: root.expandedRowIdx === 0
            selActionIndex: root.expandedRowIdx === 0 ? root.selRowAction : -1
            actions: root.rowActions(0)
            onToggled: root.toggleRowDropdown(0)
            onActionTriggered: (idx) => root.triggerRowAction(0, idx)
        }

        OpRow {
            index: -1
            modelData: null
            visible: root.hasInput
            name: "Width: " + root.gifWidthOpts[root.gifWidthIdx]
                  + (root.gifWidthOpts[root.gifWidthIdx] === "source" ? "" : " px")
            desc: "Click to pick"
            isSelected: root.inSection && 1 === root.selDevice
            isExpanded: root.expandedRowIdx === 1
            selActionIndex: root.expandedRowIdx === 1 ? root.selRowAction : -1
            actions: root.rowActions(1)
            onToggled: root.toggleRowDropdown(1)
            onActionTriggered: (idx) => root.triggerRowAction(1, idx)
        }

        OpRow {
            index: -1
            modelData: null
            visible: root.hasInput
            name: "Create GIF"
            desc: "palettegen two-pass — trim first for a short clip"
            isSelected: root.inSection && 2 === root.selDevice
            isExpanded: root.expandedRowIdx === 2
            selActionIndex: root.expandedRowIdx === 2 ? root.selRowAction : -1
            actions: root.rowActions(2)
            onToggled: root.toggleRowDropdown(2)
            onActionTriggered: (idx) => root.triggerRowAction(2, idx)
        }
    }

    // ================= Merge =================

    Column {
        id: mergeColumn
        width: parent.width
        spacing: root.colSpacing
        visible: root.selSection === root.secMerge

        NoFileLabel {}

        SectionSubHeader {
            visible: root.hasInput
            text: "Replace the video's audio with another file's track"
        }

        OpRow {
            index: -1
            modelData: null
            visible: root.hasInput
            name: "Audio: " + (root.audioPath !== "" ? root.baseName(root.audioPath) : "none")
            desc: "Click for options"
            isSelected: root.inSection && 0 === root.selDevice
            isExpanded: root.expandedRowIdx === 0
            selActionIndex: root.expandedRowIdx === 0 ? root.selRowAction : -1
            actions: root.rowActions(0)
            onToggled: root.toggleRowDropdown(0)
            onActionTriggered: (idx) => root.triggerRowAction(0, idx)
        }

        OpRow {
            index: -1
            modelData: null
            visible: root.hasInput
            name: "Merge → MKV"
            desc: "copy both streams — instant, any codec"
            isSelected: root.inSection && 1 === root.selDevice
            isExpanded: root.expandedRowIdx === 1
            selActionIndex: root.expandedRowIdx === 1 ? root.selRowAction : -1
            actions: root.rowActions(1)
            onToggled: root.toggleRowDropdown(1)
            onActionTriggered: (idx) => root.triggerRowAction(1, idx)
        }

        OpRow {
            index: -1
            modelData: null
            visible: root.hasInput
            name: "Merge → MP4"
            desc: "video copy, audio → AAC"
            isSelected: root.inSection && 2 === root.selDevice
            isExpanded: root.expandedRowIdx === 2
            selActionIndex: root.expandedRowIdx === 2 ? root.selRowAction : -1
            actions: root.rowActions(2)
            onToggled: root.toggleRowDropdown(2)
            onActionTriggered: (idx) => root.triggerRowAction(2, idx)
        }
    }

    // ================= Job =================

    Column {
        id: jobColumn
        width: parent.width
        spacing: root.colSpacing
        visible: root.selSection === root.secJob

        EmptyLabel {
            visible: jobRunner.phase === "idle"
            text: "No job has run yet"
        }

        Item {
            visible: jobRunner.phase !== "idle"
            width: parent.width
            height: root.rowHeight

            ThemeText {
                text: jobRunner.label
                anchors { left: parent.left; leftMargin: Theme.margin; right: parent.right; rightMargin: Theme.margin }
                y: 4; font.bold: true
            }

            ThemeText {
                text: {
                    switch (jobRunner.phase) {
                    case "running":
                        return "Running — " + Math.round(jobRunner.progress * 100) + "%  ("
                             + root.fmtTime(jobRunner.outTimeSec) + " / " + root.fmtTime(jobRunner.durationSec) + ")"
                    case "done":      return "Done"
                    case "failed":    return "Failed"
                    case "cancelled": return "Cancelled (partial output removed)"
                    default:          return ""
                    }
                }
                anchors { left: parent.left; leftMargin: Theme.margin; right: parent.right; rightMargin: Theme.margin; top: parent.top; topMargin: 24 }
                color: jobRunner.phase === "failed" ? Colors.critical
                     : jobRunner.phase === "done"   ? Colors.success
                     : Qt.alpha(Colors.foreground, Theme.alphaDim)
            }
        }

        Rectangle {
            visible: jobRunner.phase === "running" || jobRunner.phase === "done"
            width: parent.width - 2 * Theme.margin; x: Theme.margin
            height: Theme.meterHeight
            color: Qt.alpha(Colors.foreground, Theme.alphaInactive)

            Rectangle {
                width: parent.width * jobRunner.progress
                height: parent.height
                color: Colors.accent
            }
        }

        ThemeText {
            visible: jobRunner.output !== "" && jobRunner.phase !== "cancelled"
            text: root.tildify(jobRunner.output)
            width: parent.width
            leftPadding: Theme.margin; rightPadding: Theme.margin
            elide: Text.ElideMiddle
            color: Qt.alpha(Colors.foreground, Theme.alphaDim)
            size: "small"
        }

        DropdownRow {
            visible: jobRunner.running
            width: parent.width
            rowHeight: root.rowHeight
            isSelected: root.inSection && 0 === root.selDevice
            isExpanded: root.expandedRowIdx === 0
            selActionIndex: root.expandedRowIdx === 0 ? root.selRowAction : -1
            actions: root.rowActions(0)
            onToggled: root.toggleRowDropdown(0)
            onActionTriggered: (idx) => root.triggerRowAction(0, idx)

            ThemeText {
                text: "Cancel job"; color: Colors.critical
                anchors { left: parent.left; leftMargin: Theme.margin; verticalCenter: parent.verticalCenter }
            }
        }

        SectionSubHeader {
            visible: jobRunner.phase === "failed" && jobRunner.error !== ""
            text: "ffmpeg output"
        }

        ThemeText {
            visible: jobRunner.phase === "failed" && jobRunner.error !== ""
            text: jobRunner.error
            width: parent.width; leftPadding: Theme.margin; rightPadding: Theme.margin
            wrapMode: Text.WrapAnywhere
            color: Qt.alpha(Colors.foreground, Theme.alphaDim)
            size: "small"
        }
    }
}
