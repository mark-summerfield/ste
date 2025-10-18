# Copyright © 2025 Mark Summerfield. All rights reserved.

package require util

oo::define TextEdit method on_bs {} {
    set i [$Text index "insert linestart"]
    set j [$Text index "insert lineend"]
    if {[$Text compare $i == $j]} {
        set i [$Text index "$i -1 char"]
        set j [$Text index "$j +1 char"]
        $Text tag remove bindent0 $i $j
        $Text tag remove bindent1 $i $j
    }
}

oo::define TextEdit method on_ctrl_bs {} {
    set i [$Text index "insert -1 char"]
    set x [$Text index "$i wordstart"]
    set y [$Text index "$x wordend"]
    $Text delete $x $y
}

oo::define TextEdit method on_return {} {
    set i [$Text index "insert -1 char"]
    set i [$Text index "$i linestart"]
    set line [$Text get $i "$i lineend"]
    $Text insert insert \n
    regexp {^\s*•\s+} $line bullet
    regexp {^\s+} $line ws
    if {[info exists bullet] && $bullet ne ""} {
        if {"bindent1" in [$Text tag names insert] || \
                ([info exists ws] && $ws ne "")} {
            $Text insert insert "• " bindent1
        } else {
            $Text insert insert "• " bindent0
        }
    } elseif {[info exists ws] && $ws ne ""} {
        $Text insert insert ${ws} NtextTab
    }
    return -code break
}

oo::define TextEdit method on_tab {} {
    set i [$Text index "insert -1 char"]
    set i [$Text index "$i linestart"]
    set j [$Text index "$i lineend"]
    set line [$Text get $i $j]
    if {[string match "• " $line]} {
        $Text tag add bindent1 $i "$j +1 char"
        return -code break
    }
}

oo::define TextEdit method on_single_quote {} {
    $Text insert insert ’
    return -code break
}

oo::define TextEdit method on_double_click {} {
    set url [my get_whole_word]
    if {[string match ~* $url]} {
        set url file://[file home][string range $url 1 end]
    }
    if {[regexp {^(?:file|https?)://} $url]} {
        my highlight_urls
        util::open_url $url
    }
}
