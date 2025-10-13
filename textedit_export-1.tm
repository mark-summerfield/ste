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
    set out [my EnableUrls $out]
    join $out ""
}

oo::define TextEdit method EnableUrls out {
    for {set i 0} {$i < [llength $out]} {incr i} {
        set item [lindex $out $i]
        if {[string match ~* $item]} {
            set item file://[file home][string range $item 1 end]
        }
        if {[regexp {^(?:file|https?)://} $item]} {
            set item "<a href=\"$item\">$item</a>"
            ledit out $i $i $item
        }
    }
    return $out
}

oo::define TextEdit method HtmlOn tag {
    classvariable HIGHLIGHT_COLOR
    classvariable COLOR_FOR_TAG
    switch $tag {
        bold { return <b> }
        italic { return <i> }
        bolditalic { return <b><i> }
        highlight { return "<span style=\"background-color:\
            $HIGHLIGHT_COLOR;\">" }
        listindent1 { return "<div style=\"text-indent: 2em;\">" }
        listindent2 { return "<div style=\"text-indent: 4em;\">" }
        listindent3 { return "<div style=\"text-indent: 6em;\">" }
        NtextTab { return "<br>" }
        url {
            return "<span style=\"text-decoration: underline;\
                text-decoration-color: #FF8C00\">"
        }
        default {
            set color [dict getdef $COLOR_FOR_TAG $tag ""]
            if {$color ne ""} {
                return "<span style=\"color: $color;\">"
            } else {
                puts "unhandled tag '$tag'"
            }
        }
    }
}

oo::define TextEdit method HtmlOff tag {
    switch $tag {
        bold { return </b> }
        italic { return </i> }
        bolditalic { return </i></b> }
        highlight { return </span> }
        listindent1 { return </div> }
        listindent2 { return </div> }
        listindent3 { return </div> }
        NtextTab { return "" }
        url { return </span> }
        default { return </span> }
    }
}
