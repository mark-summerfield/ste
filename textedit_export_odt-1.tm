# Copyright © 2025 Mark Summerfield. All rights reserved.
#
# Adpated from Claude AI-generated code (all comments bar this are from
# the AI).
#
# Self-contained OpenDocument Text (.odt) export: `as_odt path title`
# writes a real, spec-correct .odt ZIP archive to $path and returns
# $path. There is no `from_odt` (yet) -- this is export-only.
#
# ODT is a different shape of problem to as_xml/as_html: it's a ZIP
# container (mimetype + META-INF/manifest.xml + content.xml + styles.xml
# + meta.xml), and unlike CSS classes, an ODF <text:span> or <text:p>
# references exactly ONE named style -- there's no stacking several
# classes onto one element. So a run tagged e.g. "bolditalic red" needs
# its own single automatic style declaring bold+italic+red all at once,
# and that style has to be declared in <office:automatic-styles> before
# it's referenced, which means walking the whole document to collect
# every distinct paragraph-style and run-style combination actually used
# *before* content.xml's body can be written. That's the one structural
# difference from as_html's single streaming pass: this builds an actual
# intermediate paragraph/run list first (OdtDumpToParas), then makes two
# passes over it (collect styles, then emit).
#
# Tag classification (justify vs indent vs inline) and priority
# resolution are reused from textedit_export_xml-1.tm's XmlClassifyTag/
# XmlResolveTag -- both are format-agnostic -- so that file must be
# loaded first. Escaping is also shared (xml_escape/xml_escape_attr).
#
# No external zip/tclkit dependency: the archive is written by hand with
# zlib deflate + a minimal local/central-directory/EOCD writer, because
# the ODF spec requires the `mimetype` entry to be the first entry in
# the archive and stored *uncompressed* (so file(1)/magic-byte sniffing
# works), which off-the-shelf zip helpers don't reliably guarantee.

oo::define TextEdit method as_odt {path title} {
    set dump [$Text dump -text -mark -tag 1.0 "end -1 char"]
    set paras [my OdtDumpToParas $dump]
    lassign [my OdtBuildContent $paras $title] contentXml paraStyleXml \
            runStyleXml

    set mimetype "application/vnd.oasis.opendocument.text"
    set manifest [my OdtManifest]
    set styles [my OdtStyles]
    set meta [my OdtMeta $title]

    set entries {}
    lappend entries [list "mimetype" $mimetype store]
    lappend entries [list "META-INF/manifest.xml" $manifest deflate]
    lappend entries [list "meta.xml" $meta deflate]
    lappend entries [list "styles.xml" $styles deflate]
    lappend entries [list "content.xml" $contentXml deflate]

    my OdtWriteZip $path $entries
    return $path
}

# --- paragraph/run model -------------------------------------------

# Walk the dump into a list of paragraph dicts:
#   {justify TAG indent TAG children {{run {tags TAGLIST text TEXT}} ...
#                                      {mark {name NAME}} ...}}
# where TAG is a raw tk tag name (e.g. "right", "bindent1") or {}.
# This is the same lazy-seeding walk as XmlFromDump/HtmlFromDump -- see
# textedit_export_xml-1.tm for why the seed is deferred rather than
# taken immediately at paragraph-flush time.
oo::define TextEdit method OdtDumpToParas dump {
    set inlineTags {}
    set justifyStack {}
    set indentStack {}
    set justifySeen {}
    set indentSeen {}
    set pendingSeed 0

    set paraChildren {}
    set havePara 0
    set paras {}

    foreach {key value index} $dump {
        switch -- $key {
            tagon {
                switch -- [my XmlClassifyTag $value] {
                    skip {}
                    justify {
                        lappend justifyStack $value
                        if {$value ni $justifySeen} {
                            lappend justifySeen $value
                        }
                    }
                    indent {
                        lappend indentStack $value
                        if {$value ni $indentSeen} {
                            lappend indentSeen $value
                        }
                    }
                    default {
                        if {$value ni $inlineTags} {
                            lappend inlineTags $value
                        }
                    }
                }
            }
            tagoff {
                switch -- [my XmlClassifyTag $value] {
                    skip {}
                    justify {
                        set p [lsearch -exact $justifyStack $value]
                        if {$p >= 0} {
                            set justifyStack [lreplace $justifyStack $p $p]
                        }
                    }
                    indent {
                        set p [lsearch -exact $indentStack $value]
                        if {$p >= 0} {
                            set indentStack [lreplace $indentStack $p $p]
                        }
                    }
                    default {
                        set p [lsearch -exact $inlineTags $value]
                        if {$p >= 0} {
                            set inlineTags [lreplace $inlineTags $p $p]
                        }
                    }
                }
            }
            mark {
                if {$value in {insert current}} continue
                if {$pendingSeed} {
                    set justifySeen $justifyStack
                    set indentSeen $indentStack
                    set pendingSeed 0
                }
                lappend paraChildren [dict create mark [dict create name \
                        $value]]
                set havePara 1
            }
            text {
                set remaining $value
                while {1} {
                    set nlPos [string first "\n" $remaining]
                    if {$nlPos < 0} {
                        if {$remaining ne {}} {
                            if {$pendingSeed} {
                                set justifySeen $justifyStack
                                set indentSeen $indentStack
                                set pendingSeed 0
                            }
                            lappend paraChildren [dict create run \
                                [dict create tags $inlineTags \
                                    text $remaining]]
                            set havePara 1
                        }
                        break
                    }
                    set chunk [string range $remaining 0 \
                            [expr {$nlPos - 1}]]
                    if {$chunk ne {}} {
                        if {$pendingSeed} {
                            set justifySeen $justifyStack
                            set indentSeen $indentStack
                            set pendingSeed 0
                        }
                        lappend paraChildren [dict create run \
                            [dict create tags $inlineTags text $chunk]]
                    }
                    if {$pendingSeed} {
                        set justifySeen $justifyStack
                        set indentSeen $indentStack
                        set pendingSeed 0
                    }
                    lappend paras [my OdtMakeParaModel $justifySeen \
                            $indentSeen $paraChildren]
                    set paraChildren {}
                    set havePara 0
                    set justifySeen {}
                    set indentSeen {}
                    set pendingSeed 1
                    set remaining [string range $remaining \
                            [expr {$nlPos + 1}] end]
                }
            }
            default {
                # Forward-compatible passthrough (e.g. image/window, if
                # ste ever grows that support): kept as a typed child so
                # OdtBuildContent can at least skip it deliberately
                # rather than silently losing track of the paragraph.
                if {$pendingSeed} {
                    set justifySeen $justifyStack
                    set indentSeen $indentStack
                    set pendingSeed 0
                }
                lappend paraChildren [dict create other [dict create \
                        key $key value $value]]
                set havePara 1
            }
        }
    }
    if {$pendingSeed} {
        set justifySeen $justifyStack
        set indentSeen $indentStack
        set pendingSeed 0
    }
    if {$havePara} {
        lappend paras [my OdtMakeParaModel $justifySeen $indentSeen \
                $paraChildren]
    }
    return $paras
}

# Resolve the winning justify/indent tag for a paragraph (same
# priority-resolution logic as XmlMakePara/HtmlMakePara) and package it
# with its children into one paragraph-model dict.
oo::define TextEdit method OdtMakeParaModel {justifySeen indentSeen \
        paraChildren} {
    set justify [my XmlResolveTag $justifySeen {center right}]
    set indentTag {}
    if {[llength $indentSeen]} {
        set kinds {}
        foreach indent $indentSeen {
            regexp {^(bindent|tindent|nindent)[0-9]+$} $indent _ kind
            if {$kind ni $kinds} { lappend kinds $kind }
        }
        set winningKind [my XmlResolveTag $kinds {tindent bindent nindent}]
        foreach indent $indentSeen {
            if {[string match "${winningKind}*" $indent]} {
                set indentTag $indent
                break
            }
        }
    }
    dict create justify $justify indent $indentTag children $paraChildren
}

# --- style collection + content.xml assembly ------------------------

# Character-level ODF properties for one Tk tag. Returns a (possibly
# empty) list of "attr=\"value\"" fragments to go inside
# <style:text-properties .../>, plus a flag for whether this tag wants
# its run wrapped in <text:a href="...">.
oo::define TextEdit method OdtRunTagProps tag {
    classvariable COLOR_FOR_TAG
    classvariable URL_UL_COLOR
    if {[dict exists $COLOR_FOR_TAG $tag]} {
        return [list fo:color=\"[dict get $COLOR_FOR_TAG $tag]\"]
    }
    switch -- $tag {
        bold        { return {fo:font-weight="bold"} }
        italic      { return {fo:font-style="italic"} }
        bolditalic  {
            return {fo:font-weight="bold" fo:font-style="italic"}
        }
        ul - underline {
            return {style:text-underline-style="solid" 
                style:text-underline-width="auto" \
                    style:text-underline-color="font-color"}
        }
        strike      {
            return {style:text-line-through-style="solid" \
                style:text-line-through-type="single" \
                style:text-line-through-color="#FF1A1A"}
        }
        highlight   { return {fo:background-color="#FFFF00"} }
        sub         { return {style:text-position="sub 58%"} }
        sup         { return {style:text-position="super 58%"} }
        url         {
            return [list style:text-underline-style=\"solid\" \
                style:text-underline-width=\"auto\" \
                style:text-underline-color=\"$URL_UL_COLOR\" \
                fo:color=\"$URL_UL_COLOR\"]
        }
        default     { return {} }
    }
}

# Paragraph-level ODF properties (justify + hanging indent) for a
# resolved justify/indent tag pair.
oo::define TextEdit method OdtParaTagProps {justify indent} {
    set props {}
    switch -- $justify {
        center { lappend props {fo:text-align="center"} }
        right  { lappend props {fo:text-align="end"} }
    }
    if {$indent ne {}} {
        regexp {^(?:bindent|tindent|nindent)([0-9]+)$} $indent _ level
        set unit 1.27 ;# cm, ~0.5in per level -- matches the em-based
                        ;# hanging indent used in as_html's CSS
        set margin [expr {($level + 1) * $unit}]
        lappend props "fo:margin-left=\"${margin}cm\""
        lappend props "fo:text-indent=\"-${unit}cm\""
    }
    return $props
}

# Build content.xml, collecting/emitting automatic styles as they're
# first encountered (a style is only emitted once per distinct
# paragraph-tag-pair or run-tag-set actually used in the document).
oo::define TextEdit method OdtBuildContent {paras title} {
    set paraStyleNameFor [dict create]
    set runStyleNameFor [dict create]
    set paraStyleDefs {}
    set runStyleDefs {}
    set nextParaId 1
    set nextRunId 1

    set bodyXml {}
    foreach para $paras {
        set justify [dict get $para justify]
        set indent [dict get $para indent]
        set paraKey "$justify|$indent"
        if {$justify eq {} && $indent eq {}} {
            set paraStyleName {}
        } else {
            if {![dict exists $paraStyleNameFor $paraKey]} {
                set name "P[incr nextParaId]"
                dict set paraStyleNameFor $paraKey $name
                set props [my OdtParaTagProps $justify $indent]
                append paraStyleDefs "<style:style style:name=\"$name\"" \
                    " style:family=\"paragraph\" \
                    style:parent-style-name=\"Standard\">" \
                    "<style:paragraph-properties \
                    [join $props { }]/></style:style>\n"
            }
            set paraStyleName [dict get $paraStyleNameFor $paraKey]
        }

        set childrenXml {}
        foreach child [dict get $para children] {
            if {[dict exists $child run]} {
                set r [dict get $child run]
                set tags [dict get $r tags]
                set text [dict get $r text]
                if {[llength $tags] == 0} {
                    append childrenXml [my xml_escape $text]
                    continue
                }
                set runKey [join [lsort $tags] "+"]
                if {![dict exists $runStyleNameFor $runKey]} {
                    set name "T[incr nextRunId]"
                    dict set runStyleNameFor $runKey $name
                    # Dedupe by attribute name: two tags can contribute
                    # the identical property (e.g. "ul" and "underline"
                    # both set style:text-underline-*), which would
                    # otherwise produce an invalid XML element with a
                    # duplicate attribute.
                    set propsDict [dict create]
                    foreach t $tags {
                        foreach p [my OdtRunTagProps $t] {
                            set eqPos [string first "=" $p]
                            set key [string range $p 0 [expr {$eqPos - 1}]]
                            dict set propsDict $key $p
                        }
                    }
                    set props [dict values $propsDict]
                    append runStyleDefs \
                        "<style:style style:name=\"$name\"" \
                        " style:family=\"text\"><style:text-properties \
                        [join $props { }]/></style:style>\n"
                }
                set runStyleName [dict get $runStyleNameFor $runKey]
                set escText [my xml_escape $text]
                set span "<text:span \
                    text:style-name=\"$runStyleName\">$escText</text:span>"
                if {"url" in $tags} {
                    set href [my xml_escape_attr $text]
                    append childrenXml "<text:a xlink:href=\"$href\" \
                        xlink:type=\"simple\">$span</text:a>"
                } else {
                    append childrenXml $span
                }
            } elseif {[dict exists $child mark]} {
                set name [dict get $child mark name]
                append childrenXml "<text:bookmark text:name=\"[my \
                    xml_escape_attr $name]\"/>"
            }
            ;# {other ...} children (forward-compat passthrough) carry
            ;# no representable content in this schema -- skipped.
        }

        set styleAttr {}
        if {$paraStyleName ne {}} {
            set styleAttr " text:style-name=\"$paraStyleName\""
        }
        append bodyXml "<text:p$styleAttr>$childrenXml</text:p>\n"
    }

    set out "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n"
    append out "<office:document-content"
    append out " xmlns:office=\"urn:oasis:names:tc:opendocument:xmlns:office:1.0\""
    append out " xmlns:style=\"urn:oasis:names:tc:opendocument:xmlns:style:1.0\""
    append out " xmlns:text=\"urn:oasis:names:tc:opendocument:xmlns:text:1.0\""
    append out " xmlns:fo=\"urn:oasis:names:tc:opendocument:xmlns:xsl-fo-compatible:1.0\""
    append out " xmlns:xlink=\"http://www.w3.org/1999/xlink\""
    append out " office:version=\"1.2\">\n"
    append out "<office:automatic-styles>\n$paraStyleDefs$runStyleDefs</office:automatic-styles>\n"
    append out "<office:body><office:text>\n$bodyXml</office:text></office:body>\n"
    append out "</office:document-content>\n"

    list $out $paraStyleDefs $runStyleDefs
}

# --- the other package parts: manifest, styles.xml, meta.xml --------

oo::define TextEdit method OdtManifest {} {
    set out "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n"
    append out "<manifest:manifest"
    append out " xmlns:manifest=\"urn:oasis:names:tc:opendocument:xmlns:manifest:1.0\""
    append out " manifest:version=\"1.2\">\n"
    append out "<manifest:file-entry manifest:full-path=\"/\" manifest:version=\"1.2\"" \
        " manifest:media-type=\"application/vnd.oasis.opendocument.text\"/>\n"
    foreach f {content.xml styles.xml meta.xml} {
        append out "<manifest:file-entry manifest:full-path=\"$f\" manifest:media-type=\"text/xml\"/>\n"
    }
    append out "</manifest:manifest>\n"
}

oo::define TextEdit method OdtStyles {} {
    set out "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n"
    append out "<office:document-styles"
    append out " xmlns:office=\"urn:oasis:names:tc:opendocument:xmlns:office:1.0\""
    append out " xmlns:style=\"urn:oasis:names:tc:opendocument:xmlns:style:1.0\""
    append out " xmlns:fo=\"urn:oasis:names:tc:opendocument:xmlns:xsl-fo-compatible:1.0\""
    append out " office:version=\"1.2\">\n"
    append out "<office:styles>\n"
    append out "<style:default-style style:family=\"paragraph\">"
    append out "<style:text-properties style:font-name=\"Liberation Sans\" fo:font-size=\"11pt\"/>"
    append out "</style:default-style>\n"
    append out "<style:style style:name=\"Standard\" style:family=\"paragraph\" style:class=\"text\"/>\n"
    append out "</office:styles>\n"
    append out "</office:document-styles>\n"
}

oo::define TextEdit method OdtMeta title {
    set out "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n"
    append out "<office:document-meta"
    append out " xmlns:office=\"urn:oasis:names:tc:opendocument:xmlns:office:1.0\""
    append out " xmlns:dc=\"http://purl.org/dc/elements/1.1/\""
    append out " xmlns:meta=\"urn:oasis:names:tc:opendocument:xmlns:meta:1.0\""
    append out " office:version=\"1.2\">\n"
    append out "<office:meta><dc:title>[my xml_escape $title]</dc:title>" \
        "<meta:generator>ste</meta:generator></office:meta>\n"
    append out "</office:document-meta>\n"
}

# --- minimal, spec-correct ZIP writer --------------------------------

# entries: list of {name data method} triples, method "store" or
# "deflate". `mimetype` MUST be entries' first element and MUST use
# "store" -- the ODF spec requires it uncompressed and first so
# file(1)-style magic-byte sniffing works without unzipping anything.
oo::define TextEdit method OdtWriteZip {path entries} {
    set localBlob {}
    set central {}
    set offset 0
    foreach entry $entries {
        lassign $entry name data method
        # $data is a Tcl string (Unicode codepoints), but zlib/binary
        # work on byte sequences -- content.xml etc. routinely contain
        # non-ASCII characters (•, ✔, ✘, ☺, curly quotes...) that have
        # no 1-byte representation. Tcl 8.6 would silently coerce these;
        # Tcl 9 is stricter and raises "expected byte sequence" from
        # zlib crc32/deflate if given the raw Unicode string. Converting
        # to UTF-8 bytes up front fixes that *and* makes the size fields
        # below correct byte counts rather than character counts (which
        # would themselves have been wrong for multi-byte characters).
        set data [encoding convertto utf-8 $data]
        set nameBytes [encoding convertto utf-8 $name]
        set crc [zlib crc32 $data]
        set uSize [string length $data]
        if {$method eq "store"} {
            set methodCode 0
            set cData $data
        } else {
            set methodCode 8
            set cData [zlib deflate $data]
        }
        set cSize [string length $cData]

        set localHeader [binary format isssssiiiss \
            0x04034b50 20 0 $methodCode 0 0x21 $crc $cSize $uSize \
            [string length $nameBytes] 0]
        append localBlob $localHeader $nameBytes $cData

        set centralHeader [binary format issssssiiisssssii \
            0x02014b50 20 20 0 $methodCode 0 0x21 $crc $cSize $uSize \
            [string length $nameBytes] 0 0 0 0 0 $offset]
        append central $centralHeader $nameBytes

        incr offset [expr {[string length $localHeader] \
            + [string length $nameBytes] + $cSize}]
    }

    set eocd [binary format issssiis \
        0x06054b50 0 0 [llength $entries] [llength $entries] \
        [string length $central] $offset 0]

    set fh [open $path wb]
    try {
        fconfigure $fh -translation binary
        puts -nonewline $fh $localBlob
        puts -nonewline $fh $central
        puts -nonewline $fh $eocd
    } finally {
        close $fh
    }
}
