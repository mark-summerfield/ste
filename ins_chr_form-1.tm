# Copyright © 2025 Mark Summerfield. All rights reserved.

package require abstract_form
package require ref
package require ui

oo::class create InsChrForm {
    superclass AbstractForm

    variable Ch
    variable CharRadio
}

oo::define InsChrForm classmethod show {} {
    set ch [Ref new ""]
    set form [InsChrForm new $ch]
    tkwait window .inschar_form
    $ch get
}

oo::define InsChrForm constructor ch {
    set Ch $ch
    my make_widgets
    my make_layout
    my make_bindings
    next .inschar_form [callback on_cancel]
    my show_modal
}

oo::define InsChrForm method make_widgets {} {
    tk::toplevel .inschar_form
    wm resizable .inschar_form false false
    wm title .inschar_form "[tk appname] — Insert Character"
    ttk::frame .inschar_form.mf
    ttk::radiobutton .inschar_form.mf.arrow_radio -text "→ Arrow" \
        -underline 2 -value → -variable [my varname CharRadio]
    ttk::radiobutton .inschar_form.mf.bullet_radio -text "• Bullet" \
        -underline 2 -value • -variable [my varname CharRadio]
    ttk::radiobutton .inschar_form.mf.ellipsis_radio -text "… Ellipsis" \
        -underline 3 -value … -variable [my varname CharRadio]
    ttk::radiobutton .inschar_form.mf.emdash_radio -text "— Em-dash" \
        -underline 2 -value — -variable [my varname CharRadio]
    ttk::radiobutton .inschar_form.mf.pound_radio -text "£ Pound" \
        -underline 2 -value £ -variable [my varname CharRadio]
    ttk::radiobutton .inschar_form.mf.tick_radio -text "✔ Tick" \
        -underline 2 -value ✔ -variable [my varname CharRadio]
    ttk::radiobutton .inschar_form.mf.cross_radio -text "✘ Cross" \
        -underline 3 -value ✘ -variable [my varname CharRadio]
    ttk::radiobutton .inschar_form.mf.quote_radio -text "“” Quotes" \
        -underline 3 -value Q -variable [my varname CharRadio]
    ttk::frame .inschar_form.mf.uf
    ttk::radiobutton .inschar_form.mf.uf.unicode_radio -text "Unicode U+" \
        -underline 0 -value U -variable [my varname CharRadio]
    ttk::entry .inschar_form.mf.uf.unicode_entry -width 10
    ttk::button .inschar_form.mf.ok_button -text OK \
        -underline 0 -command [callback on_ok] -compound left \
        -image [ui::icon ok.svg $::ICON_SIZE]
    ttk::button .inschar_form.mf.cancel_button -text Cancel \
        -underline 0 -command [callback on_cancel] -compound left \
        -image [ui::icon close.svg $::ICON_SIZE]
    .inschar_form.mf.bullet_radio invoke
}

oo::define InsChrForm method make_layout {} {
    set opts "-padx 3 -pady 3"
    grid .inschar_form.mf.arrow_radio -row 0 -column 0 -sticky w {*}$opts
    grid .inschar_form.mf.bullet_radio -row 1 -column 0 -sticky w {*}$opts
    grid .inschar_form.mf.cross_radio -row 2 -column 0 -sticky w {*}$opts
    grid .inschar_form.mf.ellipsis_radio -row 3 -column 0 -sticky w {*}$opts
    grid .inschar_form.mf.emdash_radio -row 0 -column 1 -sticky w {*}$opts
    grid .inschar_form.mf.pound_radio -row 1 -column 1 -sticky w {*}$opts
    grid .inschar_form.mf.tick_radio -row 2 -column 1 -sticky w {*}$opts
    grid .inschar_form.mf.quote_radio -row 3 -column 1 -sticky w {*}$opts
    grid .inschar_form.mf.uf -row 5 -column 0 -columnspan 2 -sticky we \
        {*}$opts
    pack .inschar_form.mf.uf.unicode_radio -side left {*}$opts
    pack .inschar_form.mf.uf.unicode_entry -side left -fill x \
        -expand true {*}$opts
    grid .inschar_form.mf.ok_button -row 6 -column 0 -sticky e {*}$opts
    grid .inschar_form.mf.cancel_button -row 6 -column 1 -sticky w {*}$opts
    pack .inschar_form.mf -fill both -expand true
}

oo::define InsChrForm method make_bindings {} {
    bind .inschar_form <Escape> [callback on_cancel]
    bind .inschar_form <Return> [callback on_ok]
    bind .inschar_form <Alt-a> {.inschar_form.mf.arrow_radio invoke}
    bind .inschar_form <Alt-b> {.inschar_form.mf.bullet_radio invoke}
    bind .inschar_form <Alt-c> [callback on_cancel]
    bind .inschar_form <Alt-e> {.inschar_form.mf.emdash_radio invoke}
    bind .inschar_form <Alt-l> {.inschar_form.mf.ellipsis_radio invoke}
    bind .inschar_form <Alt-o> [callback on_ok]
    bind .inschar_form <Alt-p> {.inschar_form.mf.pound_radio invoke}
    bind .inschar_form <Alt-q> {.inschar_form.mf.quote_radio invoke}
    bind .inschar_form <Alt-r> {.inschar_form.mf.cross_radio invoke}
    bind .inschar_form <Alt-t> {.inschar_form.mf.tick_radio invoke}
    bind .inschar_form <Alt-u> {
        .inschar_form.mf.uf.unicode_radio invoke
        focus .inschar_form.mf.uf.unicode_entry
    }
}

oo::define InsChrForm method on_ok {} {
    if {$CharRadio eq "U"} {
        set ch [.inschar_form.mf.uf.unicode_entry get]
        if {[string is xdigit $ch]} {
            $Ch set [format %c 0x$ch]
        }
    } else {
        $Ch set $CharRadio
    }
    my delete
}

oo::define InsChrForm method on_cancel {} {
    $Ch set ""
    my delete
}
