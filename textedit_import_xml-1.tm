# Copyright © 2025 Mark Summerfield. All rights reserved.
#
# Adpated from Claude AI-generated code.
#
# Populates $Text from the XML produced by as_xml/XmlFromDump. Returns
# the `title` attribute from the root <ste> element.
#
# This is a small hand-rolled scanner rather than a call out to tdom or
# tcllib's xml package: the schema is entirely under our own control and
# is deliberately simple (flat <ste><para>(<run>|<mark/>)*</para></ste>,
# every attribute value and every <run> text node already XML-escaped by
# xml_escape/xml_escape_attr, so a raw "<" or ">" can never occur outside of
# a tag boundary). That makes a single string-scan safe and much lighter
# than pulling in a full parser.
#
# justify/indent/level attributes are turned back into the same tag names
# make_tags configures (center/right, bindent<N>/tindent<N>/nindent<N>)
# and applied to every run *and* the paragraph's line, so -justify and
# -lmargin1/-lmargin2 both see the tag on the first character of the
# line, same as Tk requires.
#
# Paragraphs are separated by inserting "\n" *before* each <para> after
# the first, rather than after each </para> -- $Text already has an
# implicit trailing newline of its own, and this mirrors the
# `dump ... "end -1 char"` convention textedit_serialize-1.tm::serialize
# uses, so a round trip via as_xml/from_xml doesn't add a spurious blank
# line at the end.

oo::define TextEdit method from_xml xml {
    set pos 0
    set len [string length $xml]
    set title {}
    set paraTags {}     ;# tags for the paragraph currently being built
    set firstPara 1

    while {$pos < $len} {
        set lt [string first "<" $xml $pos]
        if {$lt < 0} break
        # skip the <?xml ... ?> declaration, if present
        if {[string index $xml [expr {$lt + 1}]] eq "?"} {
            set qgt [string first "?>" $xml $lt]
            set pos [expr {$qgt + 2}]
            continue
        }
        set gt [string first ">" $xml $lt]
        set tag [string range $xml $lt $gt]
        set pos [expr {$gt + 1}]

        if {![regexp {^<(/?)([A-Za-z0-9_]+)(.*?)(/?)>$} $tag -> closing name attrsStr selfClose]} {
            continue
        }
        set attrs [my XmlParseAttrs $attrsStr]

        if {$closing eq "/"} {
            # </para>: nothing to do -- the separator newline for this
            # paragraph is emitted lazily, right before the *next* <para>.
            continue
        }

        switch -- $name {
            ste {
                if {[dict exists $attrs title]} {
                    set title [dict get $attrs title]
                }
            }
            para {
                if {!$firstPara} {
                    $Text insert end "\n" $paraTags
                }
                set firstPara 0
                set paraTags [my XmlParaTags $attrs]
                if {$selfClose eq "/"} {
                    # empty paragraph (blank line): nothing further to
                    # insert now: the "\n" before the *next* <para> (or,
                    # if this is the last paragraph, $Text's own implicit
                    # trailing newline) closes it out.
                }
            }
            run {
                set runTags {}
                if {[dict exists $attrs tags]} {
                    set runTags [split [dict get $attrs tags] " "]
                }
                if {$selfClose ne "/"} {
                    set closeIdx [string first "</run>" $xml $pos]
                    set text [my xml_unescape [string range $xml $pos [expr {$closeIdx - 1}]]]
                    if {$text ne {}} {
                        $Text insert end $text [concat $runTags $paraTags]
                    }
                    set pos [expr {$closeIdx + 6}] ;# strlen("</run>")
                }
            }
            mark {
                if {[dict exists $attrs name]} {
                    $Text mark set [dict get $attrs name] end
                }
            }
            default {
                # Forward-compatible passthrough elements (image, window,
                # or an unrecognised dump event) carry no text content in
                # this schema -- nothing to insert.
            }
        }
    }

    return $title
}

oo::define TextEdit classmethod xml_unescape s {
    string map {&quot; \" &lt; < &gt; > &amp; &} $s
}

# Parse `key="value"` pairs out of a raw attribute string into a dict,
# unescaping each value.
oo::define TextEdit classmethod XmlParseAttrs s {
    set result [dict create]
    foreach {whole key val} [regexp -all -inline {([A-Za-z0-9_:-]+)="([^"]*)"} $s] {
        dict set result $key [my xml_unescape $val]
    }
    return $result
}

# indent="bullet"/"indent"/"number" + level="N" -> bindent<N>/tindent<N>/nindent<N>
oo::define TextEdit classmethod XmlIndentTag attrs {
    if {![dict exists $attrs indent] || ![dict exists $attrs level]} {
        return {}
    }
    set kindTag [dict get {bullet bindent indent tindent number nindent} \
        [dict get $attrs indent]]
    return "$kindTag[dict get $attrs level]"
}

# Compute the paragraph-level tag list (justify + indent) for a <para>'s
# attribute dict.
oo::define TextEdit classmethod XmlParaTags attrs {
    set tags {}
    if {[dict exists $attrs justify]} {
        lappend tags [dict get $attrs justify]
    }
    set indentTag [my XmlIndentTag $attrs]
    if {$indentTag ne {}} {
        lappend tags $indentTag
    }
    return $tags
}
