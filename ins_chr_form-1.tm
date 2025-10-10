# Copyright © 2025 Mark Summerfield. All rights reserved.

package require abstract_form
package require ref
package require ui

oo::class create InsChrForm {
    superclass AbstractForm

    variable Ch
    variable ChrRadio
}

oo::define InsChrForm initialize { variable ChrList [list] }

oo::define InsChrForm classmethod show {} {
    set ch [Ref new ""]
    set form [InsChrForm new $ch]
    tkwait window .ins_chr_form
    $ch get
}

oo::define InsChrForm constructor ch {
    classvariable ChrList
    set Ch $ch
    my make_widgets
    my make_layout
    my make_bindings
    next .ins_chr_form [callback on_cancel]
    if {[llength $ChrList]} {
        .ins_chr_form.mf.unicode_radio invoke
        set widget .ins_chr_form.mf.unicode_combo
    } else {
        .ins_chr_form.mf.bullet_radio invoke
        set widget .ins_chr_form.mf.bullet_radio
    }
    my show_modal $widget
}

oo::define InsChrForm method make_widgets {} {
    classvariable ChrList
    tk::toplevel .ins_chr_form
    wm resizable .ins_chr_form false false
    wm title .ins_chr_form "[tk appname] — Insert Character"
    ttk::frame .ins_chr_form.mf
    ttk::radiobutton .ins_chr_form.mf.arrow_radio -text "→ Arrow" \
        -underline 2 -value → -variable [my varname ChrRadio]
    ttk::radiobutton .ins_chr_form.mf.bullet_radio -text "• Bullet" \
        -underline 2 -value • -variable [my varname ChrRadio]
    ttk::radiobutton .ins_chr_form.mf.ellipsis_radio -text "… Ellipsis" \
        -underline 2 -value … -variable [my varname ChrRadio]
    ttk::radiobutton .ins_chr_form.mf.emdash_radio -text "— Em-dash" \
        -underline 3 -value — -variable [my varname ChrRadio]
    ttk::radiobutton .ins_chr_form.mf.pound_radio -text "£ Pound" \
        -underline 2 -value £ -variable [my varname ChrRadio]
    ttk::radiobutton .ins_chr_form.mf.tick_radio -text "✔ Tick" \
        -underline 2 -value ✔ -variable [my varname ChrRadio]
    ttk::radiobutton .ins_chr_form.mf.cross_radio -text "✘ Cross" \
        -underline 3 -value ✘ -variable [my varname ChrRadio]
    ttk::radiobutton .ins_chr_form.mf.quote_radio -text "“” Quotes" \
        -underline 3 -value Q -variable [my varname ChrRadio]
    ttk::radiobutton .ins_chr_form.mf.unicode_radio -text "Unicode U+" \
        -underline 0 -value U -variable [my varname ChrRadio]
    set combo [ttk::combobox .ins_chr_form.mf.unicode_combo -width 6 \
            -values [lreverse $ChrList]]
    $combo set [lindex $ChrList end]
    $combo selection range 0 end
    ttk::button .ins_chr_form.mf.ok_button -text OK \
        -underline 0 -command [callback on_ok] -compound left \
        -image [ui::icon ok.svg $::ICON_SIZE]
    ttk::button .ins_chr_form.mf.cancel_button -text Cancel \
        -underline 0 -command [callback on_cancel] -compound left \
        -image [ui::icon close.svg $::ICON_SIZE]
}

oo::define InsChrForm method make_layout {} {
    set opts "-padx 3 -pady 3"
    grid .ins_chr_form.mf.arrow_radio -row 0 -column 0 -sticky w {*}$opts
    grid .ins_chr_form.mf.bullet_radio -row 1 -column 0 -sticky w {*}$opts
    grid .ins_chr_form.mf.cross_radio -row 2 -column 0 -sticky w {*}$opts
    grid .ins_chr_form.mf.ellipsis_radio -row 3 -column 0 -sticky w {*}$opts
    grid .ins_chr_form.mf.emdash_radio -row 0 -column 1 -sticky w {*}$opts
    grid .ins_chr_form.mf.pound_radio -row 1 -column 1 -sticky w {*}$opts
    grid .ins_chr_form.mf.tick_radio -row 2 -column 1 -sticky w {*}$opts
    grid .ins_chr_form.mf.quote_radio -row 3 -column 1 -sticky w {*}$opts
    grid .ins_chr_form.mf.unicode_radio -row 4 -column 0 -sticky w \
        -padx 3 -pady 6
    grid .ins_chr_form.mf.unicode_combo -row 4 -column 1 -sticky we \
        -padx 3 -pady 6
    grid .ins_chr_form.mf.ok_button -row 5 -column 0 -sticky e {*}$opts
    grid .ins_chr_form.mf.cancel_button -row 5 -column 1 -sticky w {*}$opts
    pack .ins_chr_form.mf -fill both -expand true
}

oo::define InsChrForm method make_bindings {} {
    bind .ins_chr_form <Escape> [callback on_cancel]
    bind .ins_chr_form <Return> [callback on_ok]
    bind .ins_chr_form <Alt-a> {.ins_chr_form.mf.arrow_radio invoke}
    bind .ins_chr_form <Alt-b> {.ins_chr_form.mf.bullet_radio invoke}
    bind .ins_chr_form <Alt-c> [callback on_cancel]
    bind .ins_chr_form <Alt-e> {.ins_chr_form.mf.ellipsis_radio invoke}
    bind .ins_chr_form <Alt-m> {.ins_chr_form.mf.emdash_radio invoke}
    bind .ins_chr_form <Alt-o> [callback on_ok]
    bind .ins_chr_form <Alt-p> {.ins_chr_form.mf.pound_radio invoke}
    bind .ins_chr_form <Alt-q> {.ins_chr_form.mf.quote_radio invoke}
    bind .ins_chr_form <Alt-r> {.ins_chr_form.mf.cross_radio invoke}
    bind .ins_chr_form <Alt-t> {.ins_chr_form.mf.tick_radio invoke}
    bind .ins_chr_form <Alt-u> {
        .ins_chr_form.mf.unicode_radio invoke
        focus .ins_chr_form.mf.unicode_combo
    }
}

oo::define InsChrForm method on_ok {} {
    classvariable ChrList
    if {$ChrRadio eq "U"} {
        set ch [.ins_chr_form.mf.unicode_combo get]
        if {[string length $ch] == 1} {
            $Ch set $ch
        } elseif {[string is xdigit $ch]} {
            set ch [format %c 0x$ch]
            $Ch set $ch
            lappend ChrList $ch
        }
    } else {
        $Ch set $ChrRadio
    }
    my delete
}

oo::define InsChrForm method on_cancel {} {
    $Ch set ""
    my delete
}
