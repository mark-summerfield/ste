# Copyright © 2025-26 Mark Summerfield. All rights reserved.

package require abstract_form
package require tooltip 2
package require ui

oo::class create ConfigForm {
    superclass AbstractForm

    variable Ok
    variable Blinking
    variable Fonts
    variable FontKind ;# the font kind the font chooser is for
    variable ShowIndents
}

oo::define ConfigForm constructor ok {
    set Ok $ok
    set config [Config new]
    set Blinking [$config blinking]
    set Fonts [$config fonts]
    set ShowIndents [$config show_indents]
    my make_widgets 
    my make_layout
    my make_bindings
    next .configForm [callback on_cancel]
    my show_modal .configForm.mf.scaleSpinbox
}

oo::define ConfigForm method make_widgets {} {
    set config [Config new]
    tk::toplevel .configForm
    wm resizable .configForm 0 0
    wm title .configForm "[tk appname] — Config"
    ttk::frame .configForm.mf
    set tip tooltip::tooltip
    ttk::label .configForm.mf.scaleLabel -text "Application Scale" \
        -underline 0
    ttk::spinbox .configForm.mf.scaleSpinbox -format %.2f -from 1.0 \
        -to 10.0 -increment 0.1
    ui::apply_edit_bindings .configForm.mf.scaleSpinbox
    $tip .configForm.mf.scaleSpinbox "Application’s scale factor.\n\
        Restart to apply."
    .configForm.mf.scaleSpinbox set [format %.2f [tk scaling]]
    ttk::checkbutton .configForm.mf.showIndentsCheckbutton \
        -text "Show Indents" -underline 5 -variable [my varname ShowIndents]
    if {$ShowIndents} {
        .configForm.mf.showIndentsCheckbutton state selected
    }
    $tip .configForm.mf.showIndentsCheckbutton \
        "Whether to color highlight indents."
    ttk::checkbutton .configForm.mf.blinkCheckbutton \
        -text "Cursor Blink" -underline 7 \
        -variable [my varname Blinking]
    if {$Blinking} { .configForm.mf.blinkCheckbutton state selected }
    $tip .configForm.mf.blinkCheckbutton \
        "Whether the text cursor should blink."
    set opts "-compound left -width 15"
    foreach {kind text under} {sans Sans… 0 serif Serif… 4 mono Mono… 0
            h1 Heading\ 1… 8 h2 Heading\ 2… 8 h3 Heading\ 3… 8
            h4 Heading\ 4… 8} {
        ttk::button .configForm.mf.${kind}Button -text $text \
            -underline $under -command [callback on_font $kind] \
            -image [ui::icon preferences-desktop-font.svg $::ICON_SIZE] \
            {*}$opts
        set what [expr {[string match h? $kind]
            ? "heading [string index $kind 1]" : $kind}]
        $tip .configForm.mf.${kind}Button "The $what font to use.\nBest\
            to set the application’s scale (and restart) first."
        ttk::label .configForm.mf.${kind}Label -relief sunken \
            -text "[$config family $kind] [$config size $kind]"
    }
    ttk::label .configForm.mf.configFileLabel -foreground gray25 \
        -text "Config file"
    ttk::label .configForm.mf.configFilenameLabel -foreground gray25 \
        -text [$config filename] -relief sunken
    ttk::frame .configForm.mf.buttons
    ttk::button .configForm.mf.buttons.okButton -text OK -underline 0 \
        -compound left -image [ui::icon ok.svg $::ICON_SIZE] \
        -command [callback on_ok]
    ttk::button .configForm.mf.buttons.cancelButton -text Cancel \
        -compound left -command [callback on_cancel] \
        -image [ui::icon gtk-cancel.svg $::ICON_SIZE]
}

oo::define ConfigForm method make_layout {} {
    const opts "-padx 3 -pady 3"
    grid .configForm.mf.scaleLabel -row 0 -column 0 -sticky w {*}$opts
    grid .configForm.mf.scaleSpinbox -row 0 -column 1 -columnspan 2 \
        -sticky we {*}$opts
    set row 0
    foreach kind [set [info object namespace TextEdit]::ALL_FONT_KINDS] {
        grid .configForm.mf.${kind}Button -row [incr row] -column 0 \
                -sticky w {*}$opts
        grid .configForm.mf.${kind}Label -row $row -column 1 \
                -columnspan 2 -sticky news {*}$opts
    }
    grid .configForm.mf.showIndentsCheckbutton -row 8 -column 0 -sticky we
    grid .configForm.mf.blinkCheckbutton -row 8 -column 1 -sticky we
    grid .configForm.mf.configFileLabel -row 10 -column 0 -sticky we \
            {*}$opts
    grid .configForm.mf.configFilenameLabel -row 10 -column 1 \
            -columnspan 2 -sticky we {*}$opts
    grid .configForm.mf.buttons -row 11 -column 0 -columnspan 3 -sticky we
    pack [ttk::frame .configForm.mf.buttons.pad1] -side left -expand 1
    pack .configForm.mf.buttons.okButton -side left {*}$opts
    pack .configForm.mf.buttons.cancelButton -side left {*}$opts
    pack [ttk::frame .configForm.mf.buttons.pad2] -side right -expand 1
    grid columnconfigure .configForm.mf 1 -weight 1
    pack .configForm.mf -fill both -expand 1
}

oo::define ConfigForm method make_bindings {} {
    bind .configForm <Escape> [callback on_cancel]
    bind .configForm <Return> [callback on_ok]
    bind .configForm <Alt-a> {focus .configForm.mf.scaleSpinbox}
    bind .configForm <Alt-b> {.configForm.mf.blinkCheckbutton invoke}
    bind .configForm <Alt-s> [callback on_font sans]
    bind .configForm <Alt-f> [callback on_font serif]
    bind .configForm <Alt-m> [callback on_font mono]
    foreach n {1 2 3 4} {
        bind .configForm <Alt-Key-$n> [callback on_font h$n]
    }
    bind .configForm <Alt-i> {.configForm.mf.showIndentsCheckbutton invoke}
    bind .configForm <Alt-o> [callback on_ok]
}

oo::define ConfigForm method on_font kind {
    set FontKind $kind
    tk fontchooser configure -parent .configForm \
            -title "[tk appname] — Choose [string totitle $kind] Font" \
            -font [dict get $Fonts $kind] \
            -command [callback on_font_chosen]
    tk fontchooser show
}

oo::define ConfigForm method on_font_chosen args {
    if {[llength $args] > 0} {
        set args [lindex $args 0]
        if {[llength $args] > 1} {
            dict set Fonts $FontKind [list [lindex $args 0] \
                [lindex $args 1]]
            lassign [dict get $Fonts $FontKind] family size
            .configForm.mf.${FontKind}Label configure \
                    -text "$family $size"
        }
    }
    focus .configForm
}

oo::define ConfigForm method on_ok {} {
    set config [Config new]
    tk scaling [.configForm.mf.scaleSpinbox get]
    $config set_blinking $Blinking
    foreach kind {sans serif mono h1 h2 h3 h4} {
        $config set_font $kind {*}[dict get $Fonts $kind]
    }
    $config set_show_indents $ShowIndents
    $Ok set 1
    my delete
}

oo::define ConfigForm method on_cancel {} { my delete }
