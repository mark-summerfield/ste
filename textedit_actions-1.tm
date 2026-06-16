# Copyright © 2025 Mark Summerfield. All rights reserved.

package require util

oo::define TextEdit method on_undo {} {
    if {[$Text edit canundo]} { $Text edit undo }
}

oo::define TextEdit method on_redo {} {
    if {[$Text edit canredo]} { $Text edit redo }
}

oo::define TextEdit method on_copy {} { tk_textCopy $Text }

oo::define TextEdit method on_cut {} { tk_textCut $Text }

oo::define TextEdit method on_paste {} { tk_textPaste $Text }

oo::define TextEdit method on_bs {{brk 1}} {
    if {[string match "*.0" [$Text index insert]]} { ;# start of new line
        if {[set indent [my GetIndent]] ne ""} {
            my ReduceIndent $indent
            if {$brk} { return -code break }
            return
        }
    } else {
        set i [$Text index "insert linestart"]
        set j [$Text index "insert lineend"]
        if {[set line [$Text get $i $j]] ne ""} {
            if {[regexp {^(?:•|[1-9]\.)\s+$} $line match]} {
                set indent [my GetIndent]
                $Text delete $i "$i + [string length $match] chars"
                my ReduceIndent $indent
                if {$brk} { return -code break }
                return
            }
        }
    }
    # otherwise normal backspace delete
}

oo::define TextEdit method on_ctrl_bs {} {
    set i [$Text index "insert -1c"]
    set x [$Text index "$i wordstart"]
    set y [$Text index "$x wordend"]
    $Text delete $x $y
    return -code break
}

oo::define TextEdit method on_ctrl_del {} {
    set i [$Text index "insert +1c"]
    set x [$Text index "$i wordstart"]
    set y [$Text index "$x wordend"]
    $Text delete $x $y
    return -code break
}

oo::define TextEdit method on_ctrl_a {} { $Text tag add sel 1.0 end }

oo::define TextEdit method on_return {} {
    set i [$Text index "insert linestart"]
    set j [$Text index "insert lineend"]
    set line [$Text get $i $j]
    $Text insert insert \n
    set indent [my GetIndent]
    if {[regexp {^[•\s]+} $line match]} {
        $Text insert insert $match $indent
    } elseif {[regexp {^([1-9])\.\s+} $line match n]} {
        if {$n < 9} {
            $Text insert insert [incr n][string range $match 1 end] $indent
        }
    }
    return -code break
}

oo::define TextEdit method on_tab {{user 1} {kind 0} {brk 1}} {
    if {[string match "*.0" [$Text index insert]]} { ;# start of new line
        switch $kind {
            1 {
                $Text insert insert " • " bindent0
                set new_indent bindent0
            }
            2 {
                $Text insert insert "1. " nindent0
                set new_indent nindent0
            }
            default {
                $Text insert insert "   " tindent0
                set new_indent tindent0
            }
        }
        $Text tag add $new_indent "insert linestart" "insert lineend +1c"
        if {$brk} { return -code break }
        return
    }
    set pi [$Text index "insert -1c"]
    set pc [$Text get $pi]
    if {$Completion && $user} {
        if {[string is alnum $pc]} {
            my TryCompletion $pi
            if {$brk} { return -code break }
            return
        }
    }
    set i [$Text index "insert linestart"]
    set j [$Text index "insert lineend +1c"]
    if {[set line [$Text get $i $j]] ne ""} {
        if {[string is space $pc] && \
                [regexp {^(?:•|[1-9]\.)\s+} $line match]} {
            set indent [my GetIndent]
            my IncreaseIndent $i $j $indent $match
        }
    }
    if {$brk} { return -code break }
    return
}

oo::define TextEdit method on_ctrl_tab {{brk 1}} {
    catch {[my on_tab 0 1]}
    if {$brk} { return -code break }
}

oo::define TextEdit method on_ctrl_key_1 {{brk 1}} {
    catch {[my on_tab 0 2]}
    if {$brk} { return -code break }
}

oo::define TextEdit method TryCompletion p {
    classvariable COMMON_WORDS
    set i $p
    set i [$Text index "$p wordstart"]
    set j [$Text index "$i wordend"]
    set prefix [string tolower [$Text get $i $j]]
    if {[string trim $prefix] eq ""} { return 0 }
    set candidates [dict create]
    foreach word [list {*}$COMMON_WORDS {*}[split [$Text get 1.0 end]]] {
        set word [regsub {^\W+} [regsub {\W+$} $word ""] ""]
        set lword [string tolower $word]
        if {$lword ne "" && $prefix ne $lword && \
                [string match $prefix* $lword]} {
            dict set candidates $lword $word
        }
    }
    set possibles [lsort [dict keys $candidates]]
    switch [llength $possibles] {
        0 {}
        1 {
            set word [lindex $possibles 0]
            $Text insert insert \
                [string range $word [string length $prefix] end]
        }
        default {
            set size [string length $prefix]
            set possibles [lsort -command [callback ByLength] $possibles]
            $CompletionMenu delete 0 end 
            set n 0
            foreach lword $possibles {
                if {$n > 9 || [string length $lword] <= $size} { break }
                if {$lword eq ""} { continue }
                set word [dict get $candidates $lword]
                $CompletionMenu add command -label "$n $word" -underline 0 \
                    -command [callback Complete \
                        [string range $word [string length $prefix] end]]
                incr n
            }
            lassign [$Text bbox insert] x y
            tk_popup $CompletionMenu \
                [expr {[winfo rootx $Text] + $x + 3}] $y
        }
    }
    return 1
}

# longest to shortest or compare strings for tie-break
oo::define TextEdit classmethod ByLength {a b} {
    set asize [string length $a]
    set bsize [string length $b]
    if {$asize < $bsize} { return 1 }
    if {$asize > $bsize} { return -1 }
    string compare $a $b
}

oo::define TextEdit method Complete word { $Text insert insert $word }

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

oo::define TextEdit method ClearIndents {} {
    set i [$Text index "insert linestart"]
    set j [$Text index "insert lineend +1c"]
    $Text tag remove NtextTab $i $j
    foreach n {0 1 2} {
        $Text tag remove bindent$n $i $j
        $Text tag remove nindent$n $i $j
        $Text tag remove tindent$n $i $j
    }
}

oo::define TextEdit method GetIndent {} {
    foreach tag [$Text tag names insert] {
        if {[string match ?indent? $tag]} { return $tag }
    }
}

oo::define TextEdit method ReduceIndent indent {
    set i [$Text index "insert linestart"]
    set j [$Text index "insert lineend"]
    my ClearIndents
    switch $indent {
        bindent0 {}
        bindent1 { $Text tag add bindent0 $i $j }
        bindent2 { $Text tag add bindent1 $i $j }
        nindent0 {}
        nindent1 { $Text tag add nindent0 $i $j }
        nindent2 { $Text tag add nindent1 $i $j }
        tindent0 {}
        tindent1 { $Text tag add tindent0 $i $j }
        tindent2 { $Text tag add tindent1 $i $j }
        default {}
    }
}

oo::define TextEdit method IncreaseIndent {i j indent {match ""}} {
    $Text tag remove NtextTab $i $j
    if {$indent in {bindent0 bindent1 nindent0 nindent1 tindent0 \
                    tindent1}} {
        $Text tag remove $indent $i $j
    }
    switch $indent {
        bindent0 { $Text tag add bindent1 $i $j }
        bindent1 { $Text tag add bindent2 $i $j }
        bindent2 {}
        nindent0 {
            set n [string index $match 0]
            $Text replace $i "$i +1c" 1
            $Text tag add nindent1 $i $j
        }
        nindent1 {
            set n [string index $match 0]
            $Text replace $i "$i +1c" 1
            $Text tag add nindent2 $i $j
        }
        nindent2 {}
        tindent0 { $Text tag add tindent1 $i $j }
        tindent1 { $Text tag add tindent2 $i $j }
        tindent2 {}
        default {}
    }
}
