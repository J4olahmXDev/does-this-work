import SwiftUI

enum Palette {
    static let cream = Color(red: 0.97, green: 0.94, blue: 0.89)
    static let paper = Color(red: 0.98, green: 0.96, blue: 0.92)
    static let beige = Color(red: 0.91, green: 0.86, blue: 0.78)
    static let line = Color(red: 0.77, green: 0.70, blue: 0.60)
    static let ink = Color(red: 0.26, green: 0.20, blue: 0.16)
    static let quiet = Color(red: 0.40, green: 0.33, blue: 0.28)
    static let sage = Color(red: 0.69, green: 0.75, blue: 0.59)
    static let deepSage = Color(red: 0.33, green: 0.43, blue: 0.29)
    static let clay = Color(red: 0.81, green: 0.65, blue: 0.56)
    static let blue = Color(red: 0.65, green: 0.72, blue: 0.75)
    static let violet = Color(red: 0.75, green: 0.69, blue: 0.78)
    static let pink = Color(red: 0.84, green: 0.65, blue: 0.65)
    static let ochre = Color(red: 0.85, green: 0.73, blue: 0.52)
    static let warn = Color(red: 0.53, green: 0.29, blue: 0.22)
}

struct Art {
    var context: GraphicsContext

    func block(_ x: Double, _ y: Double, _ w: Double, _ h: Double, radius: Double = 5,
               fill: Color, line: Color = Palette.ink, width: Double = 2.2) {
        draw(Path(roundedRect: CGRect(x: x, y: y, width: w, height: h), cornerRadius: radius),
             fill: fill, line: line, width: width)
    }

    func oval(_ x: Double, _ y: Double, _ w: Double, _ h: Double, fill: Color,
              line: Color = Palette.ink, width: Double = 2.2) {
        draw(Path(ellipseIn: CGRect(x: x, y: y, width: w, height: h)),
             fill: fill, line: line, width: width)
    }

    func line(_ points: [CGPoint], color: Color = Palette.ink, width: Double = 2.4) {
        guard let first = points.first else { return }
        var path = Path()
        path.move(to: first)
        for point in points.dropFirst() { path.addLine(to: point) }
        context.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round))
    }

    func poly(_ points: [CGPoint], fill: Color, line: Color = Palette.ink, width: Double = 2.2) {
        guard let first = points.first else { return }
        var path = Path()
        path.move(to: first)
        for point in points.dropFirst() { path.addLine(to: point) }
        path.closeSubpath()
        draw(path, fill: fill, line: line, width: width)
    }

    func draw(_ path: Path, fill: Color, line: Color, width: Double) {
        context.fill(path, with: .color(fill))
        if width > 0 {
            context.stroke(path, with: .color(line), style: StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round))
        }
    }
}

func pt(_ x: Double, _ y: Double) -> CGPoint { CGPoint(x: x, y: y) }

private func artColor(_ hex: Int) -> Color {
    Color(.sRGB, red: Double((hex >> 16) & 255) / 255, green: Double((hex >> 8) & 255) / 255,
          blue: Double(hex & 255) / 255, opacity: 1)
}

private extension Art {
    func plate(_ x: Double, _ y: Double, _ w: Double, _ h: Double, radius: Double,
               _ fill: Color, _ stroke: Color, _ width: Double) {
        block(x, y, w, h, radius: radius, fill: fill, line: stroke, width: width)
    }

    func ellipse(_ x: Double, _ y: Double, _ w: Double, _ h: Double,
                 _ fill: Color, _ stroke: Color, _ width: Double) {
        oval(x, y, w, h, fill: fill, line: stroke, width: width)
    }

    func polygon(_ points: [CGPoint], _ fill: Color, _ stroke: Color, _ width: Double) {
        poly(points, fill: fill, line: stroke, width: width)
    }
}

private func roundedPolygon(_ points: [CGPoint], radius: Double) -> CGPath {
    let path = CGMutablePath()
    for i in points.indices {
        let a = points[(i + points.count - 1) % points.count]
        let b = points[i]
        let c = points[(i + 1) % points.count]
        let ab = hypot(a.x - b.x, a.y - b.y)
        let cb = hypot(c.x - b.x, c.y - b.y)
        let before = pt(b.x + (a.x - b.x) * radius / ab, b.y + (a.y - b.y) * radius / ab)
        let after = pt(b.x + (c.x - b.x) * radius / cb, b.y + (c.y - b.y) * radius / cb)
        if i == 0 { path.move(to: before) } else { path.addLine(to: before) }
        path.addQuadCurve(to: after, control: b)
    }
    path.closeSubpath()
    return path
}

private func workerShape(_ kind: WorkerArt.Kind) -> CGPath {
    switch kind {
    case .cap, .badge: CGPath(roundedRect: CGRect(x: 16, y: 19, width: 51, height: 52),
                   cornerWidth: 11, cornerHeight: 11, transform: nil)
    case .beanie, .glasses: CGPath(ellipseIn: CGRect(x: 13, y: 19, width: 57, height: 53), transform: nil)
    case .pocket: roundedPolygon([pt(27, 20), pt(56, 20), pt(70, 71), pt(12, 71)], radius: 5)
    case .goggles, .star: roundedPolygon([pt(41, 11), pt(74, 41), pt(41, 74), pt(9, 41)], radius: 5)
    case .earmuffs, .headband: CGPath(roundedRect: CGRect(x: 20, y: 14, width: 44, height: 59),
                   cornerWidth: 22, cornerHeight: 22, transform: nil)
    case .bow: roundedPolygon([pt(41, 14), pt(70, 33), pt(59, 70), pt(22, 70), pt(12, 34)], radius: 5)
    case .visor: CGPath(roundedRect: CGRect(x: 15, y: 19, width: 53, height: 53),
                   cornerWidth: 12, cornerHeight: 12, transform: nil)
    case .scarf: roundedPolygon([pt(27, 17), pt(55, 17), pt(70, 71), pt(13, 71)], radius: 5)
    }
}

struct WorkerArt: View {
    let style: String

    fileprivate enum Kind: String {
        case cap, beanie, pocket, goggles, earmuffs, bow, visor, scarf, glasses, badge, star, headband

        var colors: (body: Int, side: Int, equipment: Int) {
            switch self {
            case .cap: (0xB6C7A4, 0x9CAA89, 0x7C9473)
            case .beanie: (0xDDB192, 0xCA9A7E, 0xAF785D)
            case .pocket: (0xC8BDD4, 0xAD9FBC, 0xA394B1)
            case .goggles: (0xAABFCB, 0x8BA6B2, 0x657F8C)
            case .earmuffs: (0xBBC9C5, 0x9DAFAD, 0x899D82)
            case .bow: (0xD8AEAD, 0xBF9295, 0xC48983)
            case .visor: (0xD4C5A6, 0xBAAA8D, 0x8097A2)
            case .scarf: (0xBAABC8, 0xA297AD, 0xBC8F9B)
            case .glasses: (0xC3B3A8, 0xA99285, 0x687975)
            case .badge: (0xA7B8AF, 0x869D8F, 0xD3A867)
            case .star: (0xD0B18A, 0xB99776, 0xF3E6D2)
            case .headband: (0xB6A7C6, 0xA08EAC, 0x807086)
            }
        }
    }

    var body: some View {
        let parts = style.split(separator: ":")
        let kind = Kind(rawValue: String(parts.first ?? "")) ?? .cap
        let colors = kind.colors
        let bodyColors: (Int, Int) = switch parts.dropFirst().first {
        case "sage": (0xB6C7A4, 0x9CAA89)
        case "blue": (0xAABFCB, 0x8BA6B2)
        case "violet": (0xC8BDD4, 0xAD9FBC)
        case "pink": (0xD8AEAD, 0xBF9295)
        case "ochre": (0xD4C5A6, 0xBAAA8D)
        default: (colors.body, colors.side)
        }
        Canvas { context, size in
            var context = context
            let factor = min(size.width, size.height) / 88
            context.translateBy(x: size.width / 2 - 41 * factor, y: (size.height - 88 * factor) / 2)
            context.scaleBy(x: factor, y: factor)
            let art = Art(context: context)
            let stroke = artColor(0x493B31)
            let eye = artColor(0x342C26)
            art.oval(12, 79, 60, 6, fill: artColor(0xDAD0BF), width: 0)
            art.line([pt(29, 68), pt(29, 80), pt(33, 80)], color: stroke, width: 1.9)
            art.line([pt(52, 68), pt(52, 80), pt(56, 80)], color: stroke, width: 1.9)

            let shape = Path(workerShape(kind))
            let base = artColor(bodyColors.0)
            context.fill(shape, with: .color(base))
            var rim = Path()
            rim.move(to: pt(64, 17))
            rim.addQuadCurve(to: pt(61, 66), control: pt(64, 51))
            rim.addQuadCurve(to: pt(14, 70), control: pt(54, 76))
            for point in [pt(14, 80), pt(80, 80), pt(80, 13)] { rim.addLine(to: point) }
            rim.closeSubpath()
            var clipped = context
            clipped.clip(to: shape)
            clipped.fill(rim, with: .color(artColor(bodyColors.1)))
            context.stroke(shape, with: .color(stroke),
                           style: StrokeStyle(lineWidth: 1.95, lineCap: .round, lineJoin: .round))
            drawEquipment(kind, art: art, equipment: artColor(colors.equipment), stroke: stroke)

            let y: Double = kind == .scarf ? 49 : kind == .goggles ? 38 : 43.5
            art.oval(31, y, 3.5, 3.5, fill: eye, width: 0)
            art.oval(48, y, 3.5, 3.5, fill: eye, width: 0)
            switch kind {
            case .beanie, .bow:
                art.line([pt(39, y + 10), pt(42, y + 11), pt(45, y + 9)], color: stroke, width: 1.45)
            case .visor:
                art.line([pt(39, y + 10), pt(45, y + 9)], color: stroke, width: 1.45)
            default:
                art.line([pt(39, y + 10), pt(44, y + 10)], color: stroke, width: 1.45)
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityHidden(true)
    }

    private func drawEquipment(_ kind: Kind, art: Art, equipment: Color, stroke: Color) {
        let glass = artColor(0xEDF3EF)
        let cloth = artColor(0xF2E6D4)
        switch kind {
        case .cap:
            art.plate(27, 11, 25, 11, radius: 4, equipment, stroke, 1.65)
            art.plate(45, 18, 18, 5, radius: 2, equipment, stroke, 1.55)
            art.line([pt(35, 14), pt(42, 14)], color: cloth, width: 1)
        case .beanie:
            art.ellipse(63, 5, 8, 8, cloth, stroke, 1.4)
            art.polygon([pt(49, 10), pt(59, 9), pt(68, 14), pt(70, 22), pt(55, 25), pt(46, 19)],
                      equipment, stroke, 1.5)
            art.line([pt(49, 19), pt(68, 19)], color: cloth, width: 3)
        case .pocket:
            art.plate(49, 50, 11, 11, radius: 2, equipment, stroke, 1.35)
            art.line([pt(51, 53), pt(58, 53)], color: cloth, width: 1.0)
        case .goggles:
            art.plate(14, 36, 54, 5, radius: 2, equipment, stroke, 1.2)
            art.plate(20, 33, 42, 15, radius: 4, glass, stroke, 1.6)
            art.line([pt(41, 34), pt(41, 46)], color: equipment, width: 1)
            art.line([pt(23, 39), pt(27, 36)], color: .white, width: 1.3)
        case .earmuffs:
            let band = CGMutablePath()
            band.move(to: pt(15, 46))
            band.addQuadCurve(to: pt(41, 12), control: pt(12, 12))
            band.addQuadCurve(to: pt(69, 46), control: pt(72, 12))
            art.context.stroke(Path(band), with: .color(stroke), lineWidth: 2.4)
            art.plate(11, 41, 12, 17, radius: 4, equipment, stroke, 1.45)
            art.plate(61, 41, 12, 17, radius: 4, equipment, stroke, 1.45)
            art.line([pt(15, 45), pt(15, 54)], color: cloth, width: 1)
        case .bow:
            art.polygon([pt(46, 20), pt(49, 10), pt(59, 16), pt(68, 11), pt(71, 20), pt(64, 25), pt(58, 20)],
                      cloth, stroke, 1.5)
            art.ellipse(55, 16, 8, 7, equipment, stroke, 1.35)
        case .visor:
            art.plate(15, 17, 55, 9, radius: 3, equipment, stroke, 1.6)
            art.plate(59, 23, 18, 5, radius: 2, equipment, stroke, 1.4)
            art.line([pt(21, 20), pt(38, 20)], color: glass, width: 1)
        case .scarf:
            art.polygon([pt(52, 44), pt(61, 43), pt(67, 64), pt(58, 66)], equipment, stroke, 1.45)
            art.plate(20, 34, 43, 10, radius: 4, equipment, stroke, 1.45)
            art.line([pt(61, 60), pt(64, 66)], color: cloth, width: 1)
        case .glasses:
            art.ellipse(25, 39, 15, 13, glass, stroke, 1.55)
            art.ellipse(44, 39, 15, 13, glass, stroke, 1.55)
            art.line([pt(40, 44), pt(44, 44)], color: stroke, width: 1.3)
        case .badge:
            art.plate(49, 49, 10, 13, radius: 2, equipment, stroke, 1.25)
            art.line([pt(51, 54), pt(57, 54)], color: cloth, width: 1.2)
        case .star:
            art.polygon([pt(55, 51), pt(57, 55), pt(62, 55), pt(59, 58), pt(60, 62),
                         pt(55, 60), pt(51, 62), pt(52, 58), pt(49, 55), pt(54, 55)], equipment, stroke, 1.1)
        case .headband:
            art.plate(19, 28, 46, 9, radius: 3, equipment, stroke, 1.4)
            art.plate(24, 30, 5, 5, radius: 1, cloth, stroke, 0)
        }
    }
}

extension Station {
    var tint: Color {
        let hex: Int = switch self {
        case .large: 0x879A83
        case .medium, .sort: 0x8EA2AB
        case .small: 0xAB9C9C
        case .seal: 0xB0A589
        case .label: 0xA3ADA4
        }
        return artColor(hex)
    }
}

struct MachineArt: View {
    let station: Station

    var body: some View {
        Canvas { context, size in
            var context = context
            let factor = min(size.width / 166, size.height / 114)
            context.translateBy(x: (size.width - 166 * factor) / 2 - 11 * factor,
                                y: (size.height - 114 * factor) / 2)
            context.scaleBy(x: factor, y: factor)
            drawMachine(Art(context: context))
        }
        .accessibilityHidden(true)
    }

    private func drawMachine(_ art: Art) {
        let accent = station.tint
        let steel = artColor(0xA3ADA4)
        let steelLight = artColor(0xCBD0CA)
        let shade = artColor(0x626D64)
        let seam = artColor(0x425046)
        let warmSteel = artColor(0xB0A589)
        let face = artColor(0xF9F1E7)
        let baseShade = artColor(0xD9CFC0)
        let shadow = artColor(0x69776D)
        art.polygon([pt(12, 104), pt(154, 104), pt(177, 114), pt(29, 114)], baseShade, baseShade, 0.5)
        switch station {
        case .large:
            art.polygon([pt(126, 17), pt(147, 11), pt(147, 92), pt(126, 105)], shadow, seam, 1.6)
            art.polygon([pt(25, 17), pt(45, 11), pt(147, 11), pt(127, 17)], steelLight, seam, 1.6)
            art.plate(25, 17, 102, 88, radius: 3, accent, seam, 2)
            art.plate(37, 30, 65, 54, radius: 2, artColor(0x59665C), seam, 1.6)
            art.plate(58, 31, 17, 21, radius: 1, steelLight, seam, 1.5)
            art.plate(47, 51, 38, 8, radius: 1, steel, seam, 1.5)
            art.plate(45, 74, 46, 10, radius: 1, steelLight, seam, 1.5)
            art.plate(107, 33, 13, 35, radius: 2, steelLight, seam, 1.2)
            art.ellipse(110, 38, 7, 7, Palette.deepSage, seam, 0.8)
            art.line([pt(110, 55), pt(117, 55)], color: shade, width: 1.1)
            art.line([pt(48, 93), pt(98, 93)], color: seam, width: 1.3)
        case .medium:
            art.plate(43, 9, 93, 52, radius: 3, accent, seam, 1.8)
            art.plate(49, 17, 77, 34, radius: 2, steelLight, seam, 1.35)
            art.polygon([pt(132, 57), pt(150, 49), pt(150, 95), pt(132, 105)], shadow, seam, 1.5)
            art.plate(23, 54, 113, 51, radius: 3, accent, seam, 1.8)
            art.polygon([pt(23, 54), pt(42, 48), pt(151, 48), pt(133, 54)], steelLight, seam, 1.4)
            art.plate(34, 64, 54, 32, radius: 2, artColor(0xAAB8BE), seam, 1.25)
            art.plate(97, 64, 29, 32, radius: 2, artColor(0xAAB8BE), seam, 1.25)
            art.line([pt(99, 72), pt(111, 72)], color: seam, width: 1.2)
            art.line([pt(62, 37), pt(81, 24), pt(102, 39)], color: seam, width: 3.5)
            art.ellipse(58, 33, 9, 9, warmSteel, seam, 1.2)
            art.ellipse(76, 21, 9, 9, warmSteel, seam, 1.2)
        case .small:
            art.plate(30, 54, 106, 51, radius: 4, accent, seam, 1.8)
            art.polygon([pt(136, 54), pt(151, 47), pt(151, 96), pt(136, 105)], shade, seam, 1.5)
            art.plate(46, 34, 9, 24, radius: 2, steel, seam, 1.35)
            art.plate(114, 31, 9, 27, radius: 2, steel, seam, 1.35)
            art.plate(53, 22, 66, 26, radius: 9, face, seam, 1.6)
            art.ellipse(107, 22, 15, 26, steelLight, seam, 1.5)
            art.ellipse(112, 31, 6, 8, shade, seam, 1)
            art.polygon([pt(56, 44), pt(112, 44), pt(99, 69), pt(46, 69)], face, seam, 1.5)
            art.plate(42, 69, 72, 13, radius: 2, shade, seam, 1.5)
            art.line([pt(50, 75), pt(107, 75)], color: steelLight, width: 1.3)
        case .sort:
            art.plate(30, 63, 12, 42, radius: 1, shade, seam, 1.4)
            art.plate(128, 62, 12, 43, radius: 1, shade, seam, 1.4)
            art.plate(35, 87, 99, 7, radius: 1, steel, seam, 1.35)
            art.polygon([pt(29, 61), pt(42, 30), pt(153, 30), pt(139, 61)], steelLight, seam, 1.8)
            for offset in [0.0, 34, 68] {
                art.polygon([pt(47 + offset, 34), pt(73 + offset, 34), pt(63 + offset, 55), pt(38 + offset, 55)],
                          artColor(0x596B72), seam, 1.2)
            }
            art.plate(28, 60, 112, 20, radius: 2, accent, seam, 1.8)
            for offset in [0.0, 33, 66] { art.plate(42 + offset, 67, 14, 5, radius: 1, face, seam, 0.7) }
        case .seal:
            art.polygon([pt(136, 70), pt(151, 63), pt(151, 96), pt(136, 105)], shade, seam, 1.5)
            art.plate(25, 70, 112, 35, radius: 3, accent, seam, 1.8)
            art.plate(38, 37, 10, 33, radius: 1, steel, seam, 1.4)
            art.plate(111, 37, 10, 33, radius: 1, steel, seam, 1.4)
            art.plate(32, 28, 95, 15, radius: 3, accent, seam, 1.8)
            art.plate(49, 47, 61, 7, radius: 2, shade, seam, 1.35)
            art.plate(56, 58, 47, 12, radius: 2, face, seam, 1.35)
            art.plate(108, 78, 19, 18, radius: 2, steelLight, seam, 1.25)
            art.ellipse(113, 83, 6, 6, Station.large.tint, seam, 1)
        case .label:
            art.polygon([pt(136, 74), pt(150, 67), pt(150, 96), pt(136, 105)], shade, seam, 1.5)
            art.plate(22, 74, 115, 31, radius: 3, accent, seam, 1.8)
            art.plate(39, 38, 19, 36, radius: 2, accent, seam, 1.5)
            art.ellipse(27, 21, 45, 43, steelLight, seam, 1.8)
            art.ellipse(43, 35, 13, 13, shade, seam, 1.2)
            art.line([pt(65, 49), pt(84, 54), pt(99, 72)], color: face, width: 6)
            art.line([pt(65, 49), pt(84, 54), pt(99, 72)], color: seam, width: 1.1)
            art.plate(87, 60, 36, 14, radius: 2, Palette.clay, seam, 1.35)
            art.plate(98, 64, 13, 5, radius: 1, face, seam, 0.6)
            art.plate(99, 83, 24, 12, radius: 2, steelLight, seam, 1.15)
        }
        art.plate(18, 104, 126, 7, radius: 2, shade, seam, 1.6)
    }
}

struct FactoryWall: View {
    var body: some View {
        Canvas { context, size in
            let w = size.width
            let h = size.height
            let art = Art(context: context)
            art.block(0, 0, w, h, radius: 0, fill: Palette.beige.opacity(0.58), width: 0)
            art.line([pt(17, h * 0.34), pt(w * 0.81, h * 0.34), pt(w * 0.84, h * 0.57),
                      pt(w - 23, h * 0.57), pt(w - 23, h * 0.79)], color: Palette.line, width: 2)
            for x in [w * 0.11, w * 0.73] {
                art.block(x, h * 0.34 - 3, 6, 6, radius: 1, fill: Palette.beige, line: Palette.line, width: 1)
            }
            for x in [w * 0.23, w * 0.61] {
                art.block(x, h * 0.56, 43, 15, radius: 2, fill: Palette.cream, line: Palette.line, width: 1.1)
                for dy in [4.0, 8, 12] {
                    art.line([pt(x + 5, h * 0.56 + dy), pt(x + 38, h * 0.56 + dy)],
                             color: Palette.line, width: 0.8)
                }
            }
            art.line([pt(0, h - 0.6), pt(w, h - 0.6)], color: Palette.line, width: 1.2)
        }
        .accessibilityHidden(true)
    }
}

enum StageArtwork: Int, CaseIterable { case staffing = 1, bottleneck, plant, delivery }

struct StageIllustration: View {
    let stage: StageArtwork

    var body: some View {
        if stage == .staffing {
            HStack(spacing: 0) {
                WorkerArt(style: "cap").frame(maxWidth: 72)
                MachineArt(station: .large).frame(maxWidth: 120)
            }
            .accessibilityHidden(true)
        } else {
            Canvas { context, size in
                var context = context
                let factor = min(size.width / 160, size.height / 98)
                context.translateBy(x: (size.width - 160 * factor) / 2, y: (size.height - 98 * factor) / 2)
                context.scaleBy(x: factor, y: factor)
                let art = Art(context: context)
                switch stage {
                case .staffing:
                    break
                case .bottleneck:
                    art.block(15, 59, 131, 19, radius: 9, fill: Palette.violet)
                    for x in stride(from: 22.0, through: 127, by: 21) {
                        art.oval(x, 64, 9, 9, fill: Palette.cream, width: 1.3)
                    }
                    art.block(35, 36, 29, 23, radius: 2, fill: Palette.clay)
                    art.block(75, 31, 36, 28, radius: 2, fill: Palette.beige)
                    art.line([pt(86, 31), pt(86, 43), pt(92, 39), pt(97, 43), pt(97, 31)], width: 1.6)
                case .plant:
                    for (index, x) in [17.0, 42, 67].enumerated() {
                        art.block(x, 61 - Double(index % 2) * 3, 22, 21, radius: 3, fill: Palette.sage, width: 1.6)
                        art.oval(x + 6, 66 - Double(index % 2) * 3, 4, 7, fill: Palette.deepSage, width: 0)
                        art.oval(x + 12, 71 - Double(index % 2) * 3, 4, 7, fill: Palette.deepSage, width: 0)
                    }
                    art.poly([pt(95, 60), pt(99, 36), pt(124, 36), pt(126, 58), pt(133, 58), pt(133, 77), pt(94, 77)],
                             fill: Palette.ochre)
                    art.poly([pt(102, 57), pt(105, 41), pt(120, 41), pt(122, 57)], fill: Palette.cream, width: 1.6)
                    art.line([pt(133, 40), pt(133, 76), pt(151, 76)], width: 4)
                    art.oval(96, 71, 13, 13, fill: Palette.quiet, width: 1.3)
                    art.oval(117, 71, 13, 13, fill: Palette.quiet, width: 1.3)
                case .delivery:
                    art.block(87, 37, 55, 44, radius: 2, fill: Palette.paper)
                    art.poly([pt(84, 41), pt(90, 25), pt(139, 25), pt(145, 41)], fill: Palette.violet)
                    art.block(121, 55, 11, 24, radius: 1, fill: Palette.violet, width: 1.6)
                    art.block(95, 52, 16, 14, radius: 1, fill: Palette.blue, width: 1.6)
                    art.poly([pt(11, 73), pt(11, 58), pt(29, 48), pt(70, 48), pt(70, 73)], fill: Palette.blue)
                    art.poly([pt(18, 61), pt(31, 52), pt(38, 52), pt(38, 61)], fill: Palette.cream, width: 1.3)
                    art.oval(19, 67, 14, 14, fill: Palette.quiet, width: 1.5)
                    art.oval(51, 67, 14, 14, fill: Palette.quiet, width: 1.5)
                }
            }.accessibilityHidden(true)
        }
    }
}
