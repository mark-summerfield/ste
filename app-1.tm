# Copyright © 2025 Mark Summerfield. All rights reserved.

package require about_form
package require config
package require config_form
package require ins_char_form
package require message_form
package require ref
package require textedit
package require tooltip 2
package require ui
package require util

oo::class create App {
    variable Filename
    variable TheTextEdit
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
        my file_open
    } else {
        set textEdit [$TheTextEdit textedit]
        focus $textEdit
        $textEdit mark set insert end
        $textEdit see insert
    }
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
