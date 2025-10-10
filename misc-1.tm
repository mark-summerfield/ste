# Copyright © 2025 Mark Summerfield. All rights reserved.

namespace eval misc {}

proc misc::swatch {color size} {
    const X [expr {max(3, $size / 4.0)}]
    const Y [expr {$X + 1}]
    const SVG_TXT "<svg width=\"$size\" height=\"$size\">
        <rect x=\"0\" y=\"0\" width=\"$size\" height=\"$size\"
            rx=\"$X\" ry=\"$X\"
            style=\"fill:$color;stroke-width:$Y;stroke:white\">
        </svg>"
    image create photo -data $SVG_TXT
}
