# Copyright © 2025-26 Mark Summerfield. All rights reserved.

package require config
package require flowrow
package require textedit
package require tooltip 2
package require ui

oo::define App method make_ui {} {
    my prepare_ui
    ttk::frame .mf
    my make_toolbars
    my make_menus
    my make_widgets
    my make_layout
    my make_bindings
}

oo::define App method prepare_ui {} {
    wm title . [tk appname]
    wm iconname . [tk appname]
    wm iconphoto . -default [ui::icon icon.svg]
    wm minsize . 480 320
}

oo::define App method make_menus {} {
    menu .menu
    my make_file_menu
    my make_edit_menu
    my make_style_menu
    $Toolbars new_menu .menu {File Export Edit Headings "Bold etc." \
            Colors Special Lists Alignment}
    . configure -menu .menu
}

oo::define App method make_file_menu {} {
    menu .menu.file
    .menu add cascade -menu .menu.file -label File -underline 0
    .menu.file add command -command [callback on_file_new] -label New \
            -underline 0 -accelerator Ctrl+N -compound left \
            -image [ui::icon document-new.svg $::MENU_ICON_SIZE]
    .menu.file add command -command [callback on_file_open] -label Open… \
            -underline 0 -accelerator Ctrl+O -compound left \
            -image [ui::icon document-open.svg $::MENU_ICON_SIZE]
    .menu.file add command -command [callback on_file_import_xml] \
            -label "Import XML…" -underline 8 -compound left \
            -image [ui::icon import-xml.svg $::MENU_ICON_SIZE]
    .menu.file add command -command [callback on_file_import_html] \
            -label "Import HTML…" -underline 10 -compound left \
            -image [ui::icon import-html.svg $::MENU_ICON_SIZE]
    .menu.file add command -command [callback on_file_import_text] \
            -label "Import Text…" -underline 8 -compound left \
            -image [ui::icon import-txt.svg $::MENU_ICON_SIZE]
    .menu.file add command -command [callback on_file_save] -label Save \
            -underline 0 -accelerator Ctrl+S -compound left \
            -image [ui::icon document-save.svg $::MENU_ICON_SIZE]
    .menu.file add command -command [callback on_file_save_as] \
            -label "Save As…" -underline 5 -compound left \
            -image [ui::icon document-save-as.svg $::MENU_ICON_SIZE]
    .menu.file add separator
    .menu.file add command -command [callback on_file_export_html] \
            -label "Export as HTML" -underline 10 -compound left \
            -image [ui::icon export-html.svg $::MENU_ICON_SIZE]
    .menu.file add command -command [callback on_file_export_odt] \
            -label "Export as ODT" -underline 11 -compound left \
            -image [ui::icon export-odt.svg $::MENU_ICON_SIZE]
    .menu.file add command -command [callback on_file_export_text] \
            -label "Export as Text" -underline 10 -compound left \
            -image [ui::icon export-text.svg $::MENU_ICON_SIZE]
    .menu.file add command -command [callback on_file_export_xml] \
            -label "Export as XML" -underline 10 -compound left \
            -image [ui::icon export-xml.svg $::MENU_ICON_SIZE]
        .menu.file add command -command [callback on_file_print] \
            -label Print… -underline 0 -compound left \
            -image [ui::icon document-print.svg $::MENU_ICON_SIZE]
    .menu.file add separator
    .menu.file add command -command [callback on_config] -label Config… \
            -underline 0 -compound left \
            -image [ui::icon preferences-system.svg $::MENU_ICON_SIZE]
    .menu.file add command -command [callback on_about] -label About \
            -underline 1 -compound left \
            -image [ui::icon about.svg $::MENU_ICON_SIZE]
    .menu.file add separator
    .menu.file add command -command [callback on_quit] -label Quit \
            -underline 0 -accelerator Ctrl+Q -compound left \
            -image [ui::icon quit.svg $::MENU_ICON_SIZE]
}

oo::define App method make_edit_menu {} {
    menu .menu.edit
    .menu add cascade -menu .menu.edit -label Edit -underline 0
    .menu.edit add command -command [callback on_edit_undo] -label Undo \
            -underline 0 -accelerator Ctrl+Z -compound left \
            -image [ui::icon edit-undo.svg $::MENU_ICON_SIZE]
    .menu.edit add command -command [callback on_edit_redo] -label Redo \
            -underline 0 -accelerator Ctrl+Shift+Z -compound left \
            -image [ui::icon edit-redo.svg $::MENU_ICON_SIZE]
    .menu.edit add separator
    .menu.edit add command -command [callback on_edit_copy] -label Copy \
            -underline 0 -accelerator Ctrl+C -compound left \
            -image [ui::icon edit-copy.svg $::MENU_ICON_SIZE]
    .menu.edit add command -command [callback on_edit_cut] -label Cut \
            -underline 2 -accelerator Ctrl+X -compound left \
            -image [ui::icon edit-cut.svg $::MENU_ICON_SIZE]
    .menu.edit add command -command [callback on_edit_paste] -label Paste \
            -underline 0 -accelerator Ctrl+V -compound left \
            -image [ui::icon edit-paste.svg $::MENU_ICON_SIZE]
    .menu.edit add separator
    .menu.edit add command -command [callback on_edit_ins_chr] \
            -label "Insert Character…" -underline 0 -compound left \
            -image [ui::icon ins-char.svg $::MENU_ICON_SIZE]
    .menu.edit add separator
    .menu.edit add checkbutton -command [callback on_find_changed] \
            -label "Show Find" -underline 5 -compound left \
            -accelerator Ctrl+F -variable [my varname ShowFindPanel]
}

oo::define App method make_style_menu {} {
    menu .menu.style
    .menu add cascade -menu .menu.style -label Style -underline 0
    .menu.style add command -command [callback on_style h1] \
            -label "Heading 1" -underline 8 -compound left \
            -image [ui::icon h1.svg $::MENU_ICON_SIZE]
    .menu.style add command -command [callback on_style h2] \
            -label "Heading 2" -underline 8 -compound left \
            -image [ui::icon h2.svg $::MENU_ICON_SIZE]
    .menu.style add command -command [callback on_style h3] \
            -label "Heading 3" -underline 8 -compound left \
            -image [ui::icon h3.svg $::MENU_ICON_SIZE]
    .menu.style add command -command [callback on_style h4] \
            -label "Heading 4" -underline 8 -compound left \
            -image [ui::icon h4.svg $::MENU_ICON_SIZE]
    .menu.style add separator
    .menu.style add command -command [callback on_style bold] \
            -label Bold -underline 0 -compound left -accelerator Ctrl+B \
            -image [ui::icon format-text-bold.svg $::MENU_ICON_SIZE]
    .menu.style add command -command [callback on_style italic] \
            -label Italic -underline 0 -compound left -accelerator Ctrl+I \
            -image [ui::icon format-text-italic.svg $::MENU_ICON_SIZE]
    .menu.style add command -command [callback on_style ul] \
            -label Underline -underline 2 -compound left \
            -image [ui::icon format-text-underline.svg $::MENU_ICON_SIZE]
    menu .menu.style.fonts
    .menu.style add cascade -menu .menu.style.fonts -label Font \
            -underline 0 -compound left \
            -image [ui::icon preferences-desktop-font.svg \
                $::MENU_ICON_SIZE]
    TextEdit make_font_menu .menu.style.fonts [callback on_style_font]
    menu .menu.style.colors
    .menu.style add cascade -menu .menu.style.colors -label Color \
            -underline 0 -compound left \
            -image [ui::icon color.svg $::MENU_ICON_SIZE]
    TextEdit make_color_menu .menu.style.colors [callback on_style_color]
    .menu.style add command -command [callback on_style highlight] \
            -label Highlight -underline 0 -compound left \
            -image [ui::icon draw-highlight.svg $::MENU_ICON_SIZE]
    .menu.style add command -command [callback on_style strike] \
            -label Strikeout -underline 4 -compound left \
            -image [ui::icon format-text-strikethrough.svg \
                $::MENU_ICON_SIZE]
    .menu.style add separator
    .menu.style add command -command [callback on_style sub] \
            -label Subscript -underline 0 -compound left \
            -image [ui::icon subscript.svg $::MENU_ICON_SIZE]
    .menu.style add command -command [callback on_style sup] \
            -label Superscript -underline 3 -compound left \
            -image [ui::icon superscript.svg $::MENU_ICON_SIZE]
    .menu.style add separator
    .menu.style add command -command [callback on_style_insert_bullet] \
            -label "Insert Bullet Point" -underline 14 -compound left \
            -accelerator Ctrl+Tab -image [ui::icon bullet-list.svg \
                $::MENU_ICON_SIZE]
    .menu.style add command -command [callback on_style_insert_number] \
            -label "Insert Numbered Point" -underline 7 -compound left \
            -accelerator Ctrl+1 -image [ui::icon numbered-list.svg \
                $::MENU_ICON_SIZE]
    .menu.style add command \
            -command [callback on_style_indent_or_complete] \
            -accelerator Tab -label "Indent or Complete" -underline 5 \
            -compound left -image [ui::icon format-indent-more.svg \
                $::MENU_ICON_SIZE]
    .menu.style add command -command [callback on_style_unindent] \
            -label "Unindent" -underline 0 -compound left \
            -accelerator Backspace -image [ui::icon format-indent-less.svg \
                $::MENU_ICON_SIZE]
    .menu.style add separator
    .menu.style add command -command [callback on_style_align left] \
            -label "Left Align" -underline 0 -compound left \
            -image [ui::icon format-justify-left.svg $::MENU_ICON_SIZE]
    .menu.style add command -command [callback on_style_align center] \
            -label "Center Align" -underline 7 -compound left \
            -image [ui::icon format-justify-center.svg $::MENU_ICON_SIZE]
    .menu.style add command -command [callback on_style_align right] \
            -label "Right Align" -underline 0 -compound left \
            -image [ui::icon format-justify-right.svg $::MENU_ICON_SIZE]
}

oo::define App method make_toolbars {} {
    set Toolbars [flowrow::Row new .mf.tb]
    my make_file_toolbar
    my make_edit_toolbar
    my make_style_toolbars
}

oo::define App method make_file_toolbar {} {
    set tip tooltip::tooltip
    ttk::frame .mf.tb.file
    ttk::button .mf.tb.file.file_new -style Toolbutton \
            -command [callback on_file_new] \
            -image [ui::icon document-new.svg $::ICON_SIZE]
    $tip .mf.tb.file.file_new "File New"
    ttk::button .mf.tb.file.file_open -style Toolbutton \
            -command [callback on_file_open] \
            -image [ui::icon document-open.svg $::ICON_SIZE]
    $tip .mf.tb.file.file_open "File Open"
    ttk::button .mf.tb.file.file_save -style Toolbutton \
            -command [callback on_file_save] \
            -image [ui::icon document-save.svg $::ICON_SIZE]
    $tip .mf.tb.file.file_save "File Save"
    $Toolbars add_toolbar .mf.tb.file
    ttk::frame .mf.tb.export
    ttk::button .mf.tb.export.export_html -style Toolbutton \
            -command [callback on_file_export_html] \
            -image [ui::icon export-html.svg $::ICON_SIZE]
    $tip .mf.tb.export.export_html "Export as HTML"
    ttk::button .mf.tb.export.export_odt -style Toolbutton \
            -command [callback on_file_export_odt] \
            -image [ui::icon export-odt.svg $::ICON_SIZE]
    $tip .mf.tb.export.export_odt "Export as ODT"
    ttk::button .mf.tb.export.export_text -style Toolbutton \
            -command [callback on_file_export_text] \
            -image [ui::icon export-text.svg $::ICON_SIZE]
    $tip .mf.tb.export.export_text "Export as Text"
    ttk::button .mf.tb.export.export_xml -style Toolbutton \
            -command [callback on_file_export_xml] \
            -image [ui::icon export-xml.svg $::ICON_SIZE]
    $tip .mf.tb.export.export_xml "Export as XML"
    $Toolbars add_toolbar .mf.tb.export
}

oo::define App method make_edit_toolbar {} {
    set tip tooltip::tooltip
    ttk::frame .mf.tb.edit
    ttk::button .mf.tb.edit.edit_undo -style Toolbutton -takefocus 0 \
            -command [callback on_edit_undo] \
            -image [ui::icon edit-undo.svg $::ICON_SIZE]
    $tip .mf.tb.edit.edit_undo "Edit Undo"
    ttk::button .mf.tb.edit.edit_redo -style Toolbutton -takefocus 0 \
            -command [callback on_edit_redo] \
            -image [ui::icon edit-redo.svg $::ICON_SIZE]
    $tip .mf.tb.edit.edit_redo "Edit Redo"
    ttk::button .mf.tb.edit.edit_copy -style Toolbutton -takefocus 0 \
            -command [callback on_edit_copy] \
            -image [ui::icon edit-copy.svg $::ICON_SIZE]
    $tip .mf.tb.edit.edit_copy "Edit Copy"
    ttk::button .mf.tb.edit.edit_cut -style Toolbutton -takefocus 0 \
            -command [callback on_edit_cut] \
            -image [ui::icon edit-cut.svg $::ICON_SIZE]
    $tip .mf.tb.edit.edit_cut "Edit Cut"
    ttk::button .mf.tb.edit.edit_paste -style Toolbutton -takefocus 0 \
            -command [callback on_edit_paste] \
            -image [ui::icon edit-paste.svg $::ICON_SIZE]
    $tip .mf.tb.edit.edit_paste "Edit Paste"
    ttk::button .mf.tb.edit.edit_ins_chr -style Toolbutton -takefocus 0 \
            -command [callback on_edit_ins_chr] \
            -image [ui::icon ins-char.svg $::ICON_SIZE]
    $tip .mf.tb.edit.edit_ins_chr "Edit Insert Character…"
    $Toolbars add_toolbar .mf.tb.edit
}

oo::define App method make_style_toolbars {} {
    set tip tooltip::tooltip
    ttk::frame .mf.tb.h
    ttk::button .mf.tb.h.h1 -style Toolbutton -takefocus 0 \
            -command [callback on_style h1] \
            -image [ui::icon h1.svg $::ICON_SIZE]
    $tip .mf.tb.h.h1 "Heading 1"
    ttk::button .mf.tb.h.h2 -style Toolbutton -takefocus 0 \
            -command [callback on_style h2] \
            -image [ui::icon h2.svg $::ICON_SIZE]
    $tip .mf.tb.h.h2 "Heading 2"
    ttk::button .mf.tb.h.h3 -style Toolbutton -takefocus 0 \
            -command [callback on_style h3] \
            -image [ui::icon h3.svg $::ICON_SIZE]
    $tip .mf.tb.h.h3 "Heading 3"
    ttk::button .mf.tb.h.h4 -style Toolbutton -takefocus 0 \
            -command [callback on_style h4] \
            -image [ui::icon h4.svg $::ICON_SIZE]
    $tip .mf.tb.h.h4 "Heading 4"
    $Toolbars add_toolbar .mf.tb.h
    ttk::frame .mf.tb.style1
    ttk::button .mf.tb.style1.style_bold -style Toolbutton -takefocus 0 \
            -command [callback on_style bold] \
            -image [ui::icon format-text-bold.svg $::ICON_SIZE]
    $tip .mf.tb.style1.style_bold "Style Bold"
    ttk::button .mf.tb.style1.style_italic -style Toolbutton -takefocus 0 \
            -command [callback on_style italic] \
            -image [ui::icon format-text-italic.svg $::ICON_SIZE]
    $tip .mf.tb.style1.style_italic "Style Italic"
    ttk::button .mf.tb.style1.style_underline -style Toolbutton \
            -takefocus 0 -command [callback on_style ul] \
            -image [ui::icon format-text-underline.svg $::ICON_SIZE]
    $tip .mf.tb.style1.style_underline "Style Underline"
    menu .mf._style_fonts_menu
    ttk::menubutton .mf.tb.style1.style_fonts -style Toolbutton \
            -takefocus 0 -menu .mf._style_fonts_menu \
            -image [ui::icon preferences-desktop-font.svg $::ICON_SIZE]
    $tip .mf.tb.style1.style_fonts "Style Font"
    TextEdit make_font_menu .mf._style_fonts_menu \
            [callback on_style_font]
    $Toolbars add_toolbar .mf.tb.style1
    ttk::frame .mf.tb.style2
    ttk::button .mf.tb.style2.style_highlight -style Toolbutton \
            -takefocus 0 -command [callback on_style highlight] \
            -image [ui::icon draw-highlight.svg $::ICON_SIZE]
    menu .mf._style_colors_menu
    ttk::menubutton .mf.tb.style2.style_colors -style Toolbutton \
            -takefocus 0 -menu .mf._style_colors_menu \
            -image [ui::icon color-menu.svg $::ICON_SIZE]
    $tip .mf.tb.style2.style_colors "Style Color"
    TextEdit make_color_menu .mf._style_colors_menu \
            [callback on_style_color]
    $tip .mf.tb.style2.style_highlight "Style Highlight"
    $Toolbars add_toolbar .mf.tb.style2
    ttk::frame .mf.tb.style3
    ttk::button .mf.tb.style3.style_strike -style Toolbutton -takefocus 0 \
            -command [callback on_style strike] \
            -image [ui::icon format-text-strikethrough.svg $::ICON_SIZE]
    $tip .mf.tb.style3.style_strike "Style Strikeout"
    ttk::button .mf.tb.style3.style_sub -style Toolbutton -takefocus 0 \
            -command [callback on_style sub] \
            -image [ui::icon subscript.svg $::ICON_SIZE]
    $tip .mf.tb.style3.style_sub "Style Subscript"
    ttk::button .mf.tb.style3.style_sup -style Toolbutton -takefocus 0 \
            -command [callback on_style sup] \
            -image [ui::icon superscript.svg $::ICON_SIZE]
    $tip .mf.tb.style3.style_sup "Style Superscript"
    $Toolbars add_toolbar .mf.tb.style3
    ttk::frame .mf.tb.style4
    ttk::button .mf.tb.style4.style_bullet -style Toolbutton -takefocus 0 \
            -command [callback on_style_insert_bullet] \
            -image [ui::icon bullet-list.svg $::ICON_SIZE]
    $tip .mf.tb.style4.style_bullet "Insert Bullet Point"
    ttk::button .mf.tb.style4.style_number -style Toolbutton -takefocus 0 \
            -command [callback on_style_insert_number] \
            -image [ui::icon numbered-list.svg $::ICON_SIZE]
    $tip .mf.tb.style4.style_number "Insert Numbered Point"
    $Toolbars add_toolbar .mf.tb.style4
    ttk::frame .mf.tb.style5
    ttk::button .mf.tb.style5.style_left -style Toolbutton -takefocus 0 \
            -command [callback on_style_align left] \
            -image [ui::icon format-justify-left.svg $::ICON_SIZE]
    $tip .mf.tb.style5.style_left "Left Align"
    ttk::button .mf.tb.style5.style_center -style Toolbutton -takefocus 0 \
            -command [callback on_style_align center] \
            -image [ui::icon format-justify-center.svg $::ICON_SIZE]
    $tip .mf.tb.style5.style_center "Center Align"
    ttk::button .mf.tb.style5.style_right -style Toolbutton -takefocus 0 \
            -command [callback on_style_align right] \
            -image [ui::icon format-justify-right.svg $::ICON_SIZE]
    $tip .mf.tb.style5.style_right "Right Align"
    $Toolbars add_toolbar .mf.tb.style5
}

oo::define App method make_widgets {} {
    set config [Config new]
    set ATextEdit [TextEdit new .mf [$config family sans] \
            [$config family serif] [$config family mono] [$config size]]
    $ATextEdit show_indents [$config show_indents]
    my make_find_panel
    ttk::frame .mf.sf
    set StatusLabel [ttk::label .mf.sf.statusLabel]
}

oo::define App method make_find_panel {} {
    ttk::frame .mf.ff -relief sunken -height $::ICON_SIZE
    ttk::label .mf.ff.findLabel -text Find -underline 1
    set FindEntry [ttk::entry .mf.ff.findEntry]
    ui::apply_edit_bindings $FindEntry
    tooltip::tooltip $FindEntry "Text to find\nClick the Find button or\
        Press F3 to do or redo the find."
    ttk::button .mf.ff.findButton -text Find -underline 2 \
        -image [ui::icon edit-find.svg $::ICON_SIZE] -compound left \
        -width 9 -command [callback on_find]
    tooltip::tooltip .mf.ff.findButton "Do or redo the find."
    const opts "-pady 3 -padx 3"
    pack .mf.ff.findLabel -side left {*}$opts
    pack .mf.ff.findEntry -side left -fill both -expand 1 {*}$opts
    pack .mf.ff.findButton -side right {*}$opts
}

oo::define App method make_layout {} {
    const opts "-pady 3 -padx 3"
    grid .mf.tb -row 0 -column 0 -sticky we {*}$opts
    grid [$ATextEdit ttk_frame] -row 1 -column 0 -sticky news {*}$opts
    grid .mf.sf -row 2 -column 0 -sticky we {*}$opts
    pack .mf.sf.statusLabel -expand 1 -fill x {*}$opts
    pack [ttk::sizegrip .mf.sf.statusLabel.sizer] -side right -anchor se \
            {*}$opts
    grid rowconfigure .mf 1 -weight 1
    grid columnconfigure .mf 0 -weight 1
    pack .mf -fill both -expand 1
}

oo::define App method make_bindings {} {
    bind .mf.ff.findEntry <Return> {.mf.ff.findButton invoke}
    bind . <F3> {.mf.ff.findButton invoke}
    bind . <Control-b> [callback on_style bold]
    # Auto: Control-c Copy
    bind . <Control-e> [callback on_style_align center]
    bind . <Control-f> {.menu.edit invoke last}
    bind . <Control-i> [callback on_style italic]
    bind . <Alt-i> {focus .mf.ff.findEntry}
    bind . <Control-l> [callback on_style_align left]
    bind . <Control-n> [callback on_file_new]
    bind . <Alt-n> {.mf.ff.findButton invoke}
    bind . <Control-o> [callback on_file_open]
    bind . <Control-p> [callback on_file_print]
    bind . <Control-q> [callback on_quit]
    bind . <Control-r> [callback on_style_align right]
    bind . <Control-s> [callback on_file_save]
    # Auto: Control-v Paste
    # Auto: Control-x Cut
    # Auto: Control-z Undo
    # Auto: Control-Shift-z Redo
    wm protocol . WM_DELETE_WINDOW [callback on_quit]
}
