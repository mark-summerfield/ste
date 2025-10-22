# Copyright © 2025 Mark Summerfield. All rights reserved.

package require lambda 1

oo::define TextEdit method as_text {} {
    set lines [list]
    foreach line [split [$Text get 1.0 end] \n] {
        lappend lines [textutil::adjust $line -length 76]
    }
    join $lines \n
}

oo::define TextEdit method as_html filename {
    set txt_dump [$Text dump -text -mark -tag 1.0 "end -1 char"]
    set title [html::html_entities [file rootname [file tail $filename]]]
    set out [list "<html>\n<head><title>$title</title></head>\n<body>\n"]
    set pending [list]
    set flip true
    set tabize [lambda x {string repeat "&nbsp;" \
        [expr {4 * [string length $x]}]}]
    foreach {key value index} $txt_dump {
        switch $key {
            text {
                if {$value eq "\n"} {
                    lappend out </p>\n
                    set flip true
                } else {
                    if {$flip} {
                        lappend out \n<p>\n
                        set flip false
                    }
                    lappend out [regsub -command {^\s+} \
                        [html::html_entities $value] $tabize]
                    
                }
            }
            tagon {
                if {$flip} {
                    lappend out \n<p>\n
                    set flip false
                }
                lappend out [my HtmlOn $value]
                lappend pending $value
            }
            tagoff {
                lappend out [my HtmlOff $value]
                lpop pending
            }
        }
    }
    while {[llength $pending]} {
        set value [lpop pending]
        lappend out [my HtmlOff $value]
    }
    lappend out "\n</p>\n</body>\n</html>\n"
    my FixupItems out
    set lines [split [join $out ""] \n]
    my FixupLines lines
    join $lines \n
}

oo::define TextEdit method FixupItems out {
    upvar 1 $out out_
    for {set i 0} {$i < [llength $out_]} {incr i} {
        set item [lindex $out_ $i]
        if {[string match ~* $item]} {
            set item file://[file home][string range $item 1 end]
        }
        if {[regexp {^(?:file|https?)://} $item]} {
            set url $item
            if {[string index $url end] eq "."} {
                set url [string range $url 0 end-1]
            }
            ledit out_ $i $i "<a href=\"$url\">$item</a>"
        }
    }
}

oo::define TextEdit method FixupLines lines {
    upvar 1 $lines lines_
    for {set i 0} {$i < [llength $lines_]} {incr i} {
        set line [lindex $lines_ $i]
        if {[regexp {^(</?li>)?(&bull;|•)\s} $line]} {
            ledit lines_ $i $i [regsub {^(</?li>)?(&bull;|•)\s} $line \
                "<li>"]
        }
    }
}

oo::define TextEdit method HtmlOn tag {
    classvariable STRIKE_COLOR
    classvariable HIGHLIGHT_COLOR
    classvariable COLOR_FOR_TAG
    switch $tag {
        bindent0 - bindent1 { return <li> }
        bold { return <b> }
        bolditalic { return <b><i> }
        center { return "<div style=\"text-align: center;\">" }
        italic { return <i> }
        highlight { return "<span style=\"background-color:\
            $HIGHLIGHT_COLOR;\">" }
        left { return "" }
        NtextTab { return <br> }
        right { return "<div style=\"text-align: right;\">" }
        sel {}
        strike { return <del> }
        sub { return <sub> }
        sup { return <sup> }
        ul - underline { return <u> }
        url {
            return "<span style=\"text-decoration: underline;\
                text-decoration-color: #FF8C00\">"
        }
        default {
            set color [dict getdef $COLOR_FOR_TAG $tag ""]
            if {$color ne ""} {
                return "<span style=\"color: $color;\">"
            }
            puts "unhandled tag '$tag'"
        }
    }
}

oo::define TextEdit method HtmlOff tag {
    switch $tag {
        bindent0 - bindent1 { return </li> }
        bold { return </b> }
        bolditalic { return </i></b> }
        center { return </div> }
        italic { return </i> }
        highlight { return </span> }
        left { return "" }
        NtextTab { return "" }
        right { return </div> }
        sel {}
        strike { return </del> }
        sub { return </sub> }
        sup { return </sup> }
        ul - underline { return </u> }
        url { return </span> }
        default { return </span> }
    }
}
