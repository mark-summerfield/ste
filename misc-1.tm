# Copyright © 2025 Mark Summerfield. All rights reserved.

namespace eval misc {}

proc misc::swatch {color size} {
    const CORNER [expr {max(3, $size / 4.0)}]
    const SVG_TXT "<svg width=\"$size\" height=\"$size\">
        <rect x=\"0\" y=\"0\" width=\"$size\" height=\"$size\"
            rx=\"$CORNER\" ry=\"$CORNER\" fill=\"$color\">
        </svg>"
    image create photo -data $SVG_TXT
}
