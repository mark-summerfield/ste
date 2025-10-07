# Copyright © 2025 Mark Summerfield. All rights reserved.

package require about_form
package require config
package require config_form
package require message_form
package require ref
package require textx
package require ui
package require util

const STE_FILES {{{ste files} {.ste}}}
const SHORT_TIMEOUT 5_000
const LONG_TIMEOUT 20_000

oo::class create App {
    variable Filename
    variable TextEdit
    variable StatusLabel
}

oo::define App constructor {} {
    ui::wishinit
    tk appname ste
    set config [Config new] ;# we need tk scaling done early
    set Filename [expr {$::argc ? [lindex $::argv 0] : ""}]
    if {$Filename eq ""} { set Filename [$config lastfile] }
    my make_ui
}

oo::define App method show {} {
    wm deiconify .
    set config [Config new]
    wm geometry . [$config geometry]
    raise .
    update
    if {$Filename ne ""} {
        my do_open
    } else {
        focus $TextEdit
        $TextEdit mark set insert end
    }
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
    .menu.file add command -command [callback on_new] -label New \
            -underline 0 -accelerator Ctrl+N -compound left \
            -image [ui::icon document-new.svg $::MENU_ICON_SIZE]
    .menu.file add command -command [callback on_open] -label Open… \
            -underline 0 -accelerator Ctrl+O -compound left \
            -image [ui::icon document-open.svg $::MENU_ICON_SIZE]
    .menu.file add command -command [callback on_save] -label Save \
            -underline 0 -accelerator Ctrl+S -compound left \
            -image [ui::icon document-save.svg $::MENU_ICON_SIZE]
    .menu.file add command -command [callback on_save_as] \
            -label "Save As…" -underline 5 -compound left \
            -image [ui::icon document-save-as.svg $::MENU_ICON_SIZE]
    .menu.file add separator
    .menu.file add command -command [callback on_export_html] \
            -label "Export as HTML" -underline 10 -compound left \
            -image [ui::icon export-html.svg $::MENU_ICON_SIZE]
    .menu.file add command -command [callback on_export_text] \
            -label "Export as Text" -underline 10 -compound left \
            -image [ui::icon export-text.svg $::MENU_ICON_SIZE]
    .menu.file add command -command [callback on_print] -label Print… \
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
    ttk::frame .mtf
    ttk::frame .mtf.tf
    set TextEdit [text .mtf.tf.txt]
    textx::make_fonts $TextEdit [$config family] [$config size]
    textx::make_tags $TextEdit
    ui::scrollize .mtf.tf txt vertical
    set StatusLabel [ttk::label .mtf.statusLabel]
}

oo::define App method make_layout {} {
    const opts "-pady 3 -padx 3"
    pack .mtf -fill both -expand true
    pack .mtf.tf -fill both -expand true
    pack .mtf.statusLabel -fill x -side bottom {*}$opts
}

oo::define App method make_bindings {} {
    bind . <Control-n> [callback on_new]
    bind . <Control-o> [callback on_open]
    bind . <Control-p> [callback on_print]
    bind . <Control-q> [callback on_quit]
    bind . <Control-s> [callback on_save]
    wm protocol . WM_DELETE_WINDOW [callback on_quit]
}

oo::define App method on_new {} {
    my on_save
    set Filename ""
    $TextEdit delete 1.0 end
    $TextEdit edit modified false
    focus $TextEdit
}

oo::define App method on_open {} {
    my on_save
    set dir [expr {$Filename eq "" ? [file home] \
                                   : [file dirname $Filename]}]
    set filename [tk_getOpenFile -initialdir $dir -filetypes $::STE_FILES \
            -title "[tk appname] — Open" -parent .]
    if {$filename ne ""} {
        set Filename $filename
        my do_open
    }
}

oo::define App method on_save {} {
    if {$Filename eq ""} { my on_save_as }
    my do_save
}

oo::define App method on_save_as {} {
    set dir [expr {$Filename eq "" ? [file home] \
                                   : [file dirname $Filename]}]
    set filename [tk_getSaveFile -initialdir $dir -filetypes $::STE_FILES \
            -title "[tk appname] — Save As" -parent .]
    if {$filename ne ""} {
        set Filename $filename
        my do_save
    }
}

oo::define App method on_export_html {} {
    if {$Filename eq ""} { my save_as }
    set filename [regsub {\.ste$} $Filename .html]
    writeFile $filename [textx::html $TextEdit]
    my show_message "Exported '$filename'"
}

oo::define App method on_export_text {} {
    if {$Filename eq ""} { my save_as }
    set filename [regsub {\.ste$} $Filename .txt]
    writeFile $filename [$TextEdit get 1.0 end]
    my show_message "Exported '$filename'"
}

oo::define App method on_print {} {
    if {[catch {tk print $TextEdit} err]} { my show_error $err }
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
            textx::make_fonts $TextEdit [$config family] [$config size]
        }
    }
}

oo::define App method on_about {} {
    AboutForm new "Styled Text Editor" \
        https://github.com/mark-summerfield/ste
}

oo::define App method on_quit {} {
    if {[$TextEdit edit modified]} { my on_save }
    set config [Config new]
    $config save $Filename
    exit
}

oo::define App method do_open {} {
    set txt_dump [zlib inflate [readFile $Filename binary]]
    textx::deserialize $TextEdit $txt_dump
    focus $TextEdit
    $TextEdit mark set insert end
    wm title . "[tk appname] — [file tail $Filename]"
    my show_message "Opened '$Filename'."
}

oo::define App method do_save {} {
    writeFile $Filename binary [zlib deflate [textx::serialize $TextEdit] 9]
    my show_message "Saved '$Filename'."
}

oo::define App method show_message msg {
    $StatusLabel configure -text $msg -foreground navy
    after $::SHORT_TIMEOUT [callback clear_status]
}

oo::define App method show_error err {
    $StatusLabel configure -text $err -foreground red
    after $::LONG_TIMEOUT [callback clear_status]
}

oo::define App method clear_status {} { $StatusLabel configure -text "" }
