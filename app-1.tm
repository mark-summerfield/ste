# Copyright © 2025 Mark Summerfield. All rights reserved.

package require about_form
package require config
package require config_form
package require message_form
package require ref
package require textx
package require ui
package require util

oo::class create App {
    variable TextWidget
}

oo::define App constructor {} {
    ui::wishinit
    tk appname STE
    Config new ;# we need tk scaling done early
    my make_ui
}

oo::define App method show {} {
    wm deiconify .
    set config [Config new]
    wm geometry . [$config geometry]
    raise .
    update
    focus $TextWidget
}

oo::define App method make_ui {} {
    my prepare_ui
    my make_menu
    my make_widgets
    my make_layout
    my make_bindings
}

oo::define App method prepare_ui {} {
    wm title . [tk appname]
    wm iconname . [tk appname]
    wm iconphoto . -default [ui::icon icon.svg]
}

oo::define App method make_menu {} {
    menu .menu
    my make_file_menu
    my make_edit_menu
    my make_style_menu
    . configure -menu .menu
}

oo::define App method make_file_menu {} {
    menu .menu.file
    .menu add cascade -menu .menu.file -label File -underline 0
    # TODO icons
    # TODO &Open…
    # TODO &Save
    # TODO Save &As…
    .menu.file add separator
    .menu.file add command -command [callback on_config] -label Config… \
            -underline 0
    .menu.file add command -command [callback on_about] -label About \
            -underline 0
    .menu.file add separator
    .menu.file add command -command [callback on_quit] -label Quit \
            -underline 0 -accelerator Ctrl+Q
}

oo::define App method make_edit_menu {} {
    menu .menu.edit
    .menu add cascade -menu .menu.edit -label Edit -underline 0
    # TODO icons
    # TODO Undo Redo Copy Cut Paste
    # TODO Insert→Bullet Arrow ... Character…
}

oo::define App method make_style_menu {} {
    menu .menu.style
    .menu add cascade -menu .menu.style -label Style -underline 0
    # TODO icons
    # TODO Roman Bold Italic BoldItalic Highlight
    #   Color→(title-cased ColorTag names)
    #   Indent→Level 1 | Level 2 | Level 3
}

oo::define App method make_widgets {} {
    set config [Config new]
    ttk::frame .mf
    ttk::frame .mf.tf
    set TextWidget [text .mf.tf.txt]
    textx::make_fonts $TextWidget [$config family] [$config size]
    textx::make_tags $TextWidget
    ui::scrollize .mf.tf txt vertical
}

oo::define App method make_layout {} {
    const opts "-pady 3 -padx 3"
    pack .mf -fill both -expand true
    pack .mf.tf -fill both -expand true
}

oo::define App method make_bindings {} {
    bind . <Control-q> [callback on_quit]
    wm protocol . WM_DELETE_WINDOW [callback on_quit]
}

oo::define App method on_config {} {
    set config [Config new]
    set ok [Ref new false]
    set family [$config family]
    set size [$config size]
    set form [ConfigForm new $ok]
    tkwait window [$form form]
    if {[$ok get]} {
        if {$family ne [$config family] || $size != [$config size]} {
            textx::make_fonts $TextWidget [$config family] [$config size]
        }
    }
}

oo::define App method on_about {} {
    AboutForm new "Styled Text Editor" \
        https://github.com/mark-summerfield/styled
}

oo::define App method on_quit {} {
    set config [Config new]
    $config save
    exit
}

