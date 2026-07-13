# Copyright © 2025 Mark Summerfield. All rights reserved.
#
# Adpated from Claude AI-generated code (all comments bar this are from
# the AI).
#
# Populates $Text from the HTML produced by as_html/HtmlFromDump.
# Returns the title (read from <body data-title="...">).
#
# Like from_xml, this is a small hand-rolled scanner rather than a real
# HTML parser: it targets exactly the shape as_html produces (everything
# before <body> -- the <head>, the embedded <style> -- is skipped
# entirely rather than parsed, then a flat run of <p>/<span>/<a>/
# <ste-mark> within <body>). It is NOT a general-purpose HTML importer;
# hand-edited or foreign HTML that uses different markup won't round-trip
# through this.
#
# Unlike from_xml's <run tags="...">text</run>, this schema allows a
# <p> to contain a mix of wrapped (<span>/<a> with a class) and bare
# (untagged) text directly, so the scanner tracks whether it is
# currently inside an open <p> and, if so, treats any text found between
# two tags as an untagged run rather than silently dropping it.

oo::define TextEdit method from_html html {
    set bodyStart [string first "<body" $html]
    if {$bodyStart < 0} { return {} }

    set pos $bodyStart
    set len [string length $html]
    set title {}
    set paraTags {}
    set firstPara 1
    set insideP 0

    while {$pos < $len} {
        set lt [string first "<" $html $pos]
        if {$lt < 0} break

        # Bare text sitting directly inside the current <p>, i.e. text
        # not wrapped in <span>/<a> -- the runs a plain xml_escape (no
        # tags) round-trips to.
        if {$lt > $pos && $insideP} {
            set text [my xml_unescape [string range $html $pos \
                    [expr {$lt - 1}]]]
            if {$text ne {}} {
                $Text insert end $text $paraTags
            }
        }

        set gt [string first ">" $html $lt]
        if {$gt < 0} break
        set tag [string range $html $lt $gt]
        set pos [expr {$gt + 1}]

        if {![regexp {^<(/?)([A-Za-z0-9_-]+)(.*?)(/?)>$} $tag _ closing \
                name attrsStr selfClose]} {
            continue
        }
        set attrs [my XmlParseAttrs $attrsStr]

        switch -- $name {
            body {
                if {$closing eq "/"} break
                if {[dict exists $attrs data-title]} {
                    set title [dict get $attrs data-title]
                }
            }
            p {
                if {$closing eq "/"} {
                    set insideP 0
                    continue
                }
                if {!$firstPara} {
                    $Text insert end "\n" $paraTags
                }
                set firstPara 0
                set paraTags {}
                if {[dict exists $attrs class]} {
                    set paraTags [split [dict get $attrs class] " "]
                }
                set insideP 1
                if {$selfClose eq "/"} { set insideP 0 }
            }
            span - a {
                if {$closing eq "/"} continue
                set runTags {}
                if {[dict exists $attrs class]} {
                    set runTags [split [dict get $attrs class] " "]
                }
                if {$selfClose ne "/"} {
                    set closeTag "</$name>"
                    set closeIdx [string first $closeTag $html $pos]
                    if {$closeIdx < 0} break
                    set text [my xml_unescape [string range $html $pos \
                            [expr {$closeIdx - 1}]]]
                    if {$text ne {}} {
                        $Text insert end $text [concat $runTags $paraTags]
                    }
                    set pos [expr {$closeIdx + [string length $closeTag]}]
                }
            }
            ste-mark {
                if {[dict exists $attrs data-name]} {
                    $Text mark set [dict get $attrs data-name] end
                }
            }
            default {
                # ste-event (forward-compat passthrough) and anything
                # else unrecognised: no text content to insert in this
                # schema, so just skip over it.
            }
        }
    }

    return $title
}
