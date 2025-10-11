# Copyright © 2025 Mark Summerfield. All rights reserved.

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
                    lappend out [html::html_entities $value]
                    
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
    join $out ""
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
        NtextTab { return "<div style=\"margin-left: 4em;\">" }
        default {
            set color [dict getdef $COLOR_FOR_TAG $tag ""]
            if {$color ne ""} { return "<span style=\"color: $color;\">" }
        }
    }
}

oo::define TextEdit method HtmlOff tag {
    switch $tag {
        bold { return </b> }
        italic { return </i> }
        bolditalic { return </i></b> }
        highlight { return </span> }
        listlistindent1 { return </div> }
        listindent2 { return </div> }
        listindent3 { return </div> }
        NtextTab { return </div> }
        default { return </span> }
    }
}
