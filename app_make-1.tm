# Copyright © 2025 Mark Summerfield. All rights reserved.

package require config
package require textedit
package require textedit_export
package require tooltip 2
package require ui

oo::define App method make_ui {} {
    my prepare_ui
    my make_menus
    ttk::frame .mf
    my make_toolbars
    my make_widgets
    my make_layout
    my make_bindings
}

oo::define App method prepare_ui {} {
    wm title . [tk appname]
    wm iconname . [tk appname]
    wm iconphoto . -default [ui::icon icon.svg]
}

oo::define App method make_menus {} {
    menu .menu
    my make_file_menu
    my make_edit_menu
    my make_style_menu
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
    .menu.file add command -command [callback on_file_export_text] \
            -label "Export as Text" -underline 10 -compound left \
            -image [ui::icon export-text.svg $::MENU_ICON_SIZE]
    .menu.file add command -command [callback on_file_print] -label Print… \
            -underline 0 -compound left \
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
    .menu.edit add command -command [callback on_edit_ins_char] \
            -label "Insert Character…" -underline 0 -compound left \
            -image [ui::icon ins-char.svg $::MENU_ICON_SIZE]
}

oo::define App method make_style_menu {} {
    menu .menu.style
    .menu add cascade -menu .menu.style -label Style -underline 0
    .menu.style add command -command [callback on_style_bold] \
            -label Bold -underline 0 -compound left -accelerator Ctrl+B \
            -image [ui::icon format-text-bold.svg $::MENU_ICON_SIZE]
    .menu.style add command -command [callback on_style_italic] \
            -label Italic -underline 0 -compound left -accelerator Ctrl+I \
            -image [ui::icon format-text-italic.svg $::MENU_ICON_SIZE]
    .menu.style add command -command [callback on_style_highlight] \
            -label Highlight -underline 0 -compound left \
            -image [ui::icon draw-highlight.svg $::MENU_ICON_SIZE]
    # TODO 
    #   Color→(title-cased ColorTag names)
    #   Indent→Level 1 | Level 2 | Level 3
}

oo::define App method make_toolbars {} {
    ttk::frame .mf.tb
    my make_file_toolbar
    my make_edit_toolbar
    my make_style_toolbar
}

oo::define App method make_file_toolbar {} {
    set tip tooltip::tooltip
    ttk::button .mf.tb.file_new -style Toolbutton \
        -command [callback on_file_new] \
        -image [ui::icon document-new.svg $::ICON_SIZE]
    $tip .mf.tb.file_new "File New"
    ttk::button .mf.tb.file_open -style Toolbutton \
        -command [callback on_file_open] \
        -image [ui::icon document-open.svg $::ICON_SIZE]
    $tip .mf.tb.file_open "File Open"
    ttk::button .mf.tb.file_save -style Toolbutton \
        -command [callback on_file_save] \
        -image [ui::icon document-save.svg $::ICON_SIZE]
    $tip .mf.tb.file_save "File Save"
}

oo::define App method make_edit_toolbar {} {
    set tip tooltip::tooltip
    ttk::button .mf.tb.edit_undo -style Toolbutton -takefocus 0 \
        -command [callback on_edit_undo] \
        -image [ui::icon edit-undo.svg $::ICON_SIZE]
    $tip .mf.tb.edit_undo "Edit Undo"
    ttk::button .mf.tb.edit_redo -style Toolbutton -takefocus 0 \
        -command [callback on_edit_redo] \
        -image [ui::icon edit-redo.svg $::ICON_SIZE]
    $tip .mf.tb.edit_redo "Edit Redo"
    ttk::button .mf.tb.edit_copy -style Toolbutton -takefocus 0 \
        -command [callback on_edit_copy] \
        -image [ui::icon edit-copy.svg $::ICON_SIZE]
    $tip .mf.tb.edit_copy "Edit Copy"
    ttk::button .mf.tb.edit_cut -style Toolbutton -takefocus 0 \
        -command [callback on_edit_cut] \
        -image [ui::icon edit-cut.svg $::ICON_SIZE]
    $tip .mf.tb.edit_cut "Edit Cut"
    ttk::button .mf.tb.edit_paste -style Toolbutton -takefocus 0 \
        -command [callback on_edit_paste] \
        -image [ui::icon edit-paste.svg $::ICON_SIZE]
    $tip .mf.tb.edit_paste "Edit Paste"
    ttk::button .mf.tb.edit_ins_char -style Toolbutton -takefocus 0 \
        -command [callback on_edit_ins_char] \
        -image [ui::icon ins-char.svg $::ICON_SIZE]
    $tip .mf.tb.edit_ins_char "Edit Insert Character…"
}

oo::define App method make_style_toolbar {} {
    set tip tooltip::tooltip
    ttk::button .mf.tb.style_bold -style Toolbutton -takefocus 0 \
        -command [callback on_style_bold] \
        -image [ui::icon format-text-bold.svg $::ICON_SIZE]
    $tip .mf.tb.style_bold "Style Bold"
    ttk::button .mf.tb.style_italic -style Toolbutton -takefocus 0 \
        -command [callback on_style_italic] \
        -image [ui::icon format-text-italic.svg $::ICON_SIZE]
    $tip .mf.tb.style_italic "Style Italic"
    ttk::button .mf.tb.style_highlight -style Toolbutton -takefocus 0 \
        -command [callback on_style_highlight] \
        -image [ui::icon draw-highlight.svg $::ICON_SIZE]
    $tip .mf.tb.style_highlight "Style Highlight"
    # TODO
}

oo::define App method make_widgets {} {
    set config [Config new]
    set TheTextEdit [TextEdit make .mf [$config family] [$config size]]
    set StatusLabel [ttk::label .mf.statusLabel]
}

oo::define App method make_layout {} {
    const opts "-pady 3 -padx 3"
    my make_toolbars_layout
    pack .mf.tb -side top -fill x {*}$opts
    pack .mf.statusLabel -side bottom -fill x  {*}$opts
    pack [ttk::sizegrip .mf.statusLabel.sizer] -side right -anchor se \
        {*}$opts
    pack .mf.[$TheTextEdit framename] -fill both -expand true {*}$opts
    pack .mf -fill both -expand true
}

oo::define App method make_toolbars_layout {} {
    const opts "-pady 3 -padx 3"
    set n 0
    pack .mf.tb.file_new -side left
    pack .mf.tb.file_open -side left
    pack .mf.tb.file_save -side left
    pack [ttk::separator .mf.tb.sep[incr n] -orient vertical] -side left \
        -fill y {*}$opts
    pack .mf.tb.edit_undo -side left
    pack .mf.tb.edit_redo -side left
    pack [ttk::separator .mf.tb.sep[incr n] -orient vertical] -side left \
        -fill y {*}$opts
    pack .mf.tb.edit_copy -side left
    pack .mf.tb.edit_cut -side left
    pack .mf.tb.edit_paste -side left
    pack [ttk::separator .mf.tb.sep[incr n] -orient vertical] -side left \
        -fill y {*}$opts
    pack .mf.tb.edit_ins_char -side left
    pack [ttk::separator .mf.tb.sep[incr n] -orient vertical] -side left \
        -fill y {*}$opts
    pack .mf.tb.style_bold -side left
    pack .mf.tb.style_italic -side left
    pack [ttk::separator .mf.tb.sep[incr n] -orient vertical] -side left \
        -fill y {*}$opts
    pack .mf.tb.style_highlight -side left
    pack [ttk::separator .mf.tb.sep[incr n] -orient vertical] -side left \
        -fill y {*}$opts
}

oo::define App method make_bindings {} {
    bind . <Control-b> [callback on_style_bold]
    # Auto: Control-c Copy
    bind . <Control-i> [callback on_style_italic]
    bind . <Control-n> [callback on_file_new]
    bind . <Control-o> [callback on_file_open]
    bind . <Control-p> [callback on_file_print]
    bind . <Control-q> [callback on_quit]
    bind . <Control-s> [callback on_file_save]
    # Auto: Control-v Paste
    # Auto: Control-x Cut
    # Auto: Control-z Undo
    # Auto: Control-Shift-z Redo
    wm protocol . WM_DELETE_WINDOW [callback on_quit]
}
