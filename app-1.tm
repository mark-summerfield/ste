# Copyright © 2025 Mark Summerfield. All rights reserved.

package require config
package require ui

oo::singleton create App {
    variable Filename
    variable ATextEdit
    variable StatusLabel
}

package require app_actions
package require app_make
package require app_support

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
    if {$Filename ne "" && [file isfile $Filename]} {
        my file_open
    } else {
        $ATextEdit clear
        $ATextEdit mark set insert end
        $ATextEdit see insert
        $ATextEdit focus
    }
    after $::POLL_TIMEOUT [callback on_poll]
}

oo::define App method show_message {msg {timeout short}} {
    $StatusLabel configure -text $msg -foreground navy
    set timeout [expr {$timeout eq "short" ? $::SHORT_TIMEOUT \
                                           : $::LONG_TIMEOUT}]
    after $timeout [callback clear_status]
}

oo::define App method show_error err {
    $StatusLabel configure -text $err -foreground red
    after $::LONG_TIMEOUT [callback clear_status]
}

oo::define App method clear_status {} { $StatusLabel configure -text "" }
