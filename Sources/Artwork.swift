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

struct WorkerArt: View {
    let style: String

    private var kind: String { style.components(separatedBy: ":")[0] }

    private var tint: Color {
        if let suffix = style.split(separator: ":").dropFirst().first {
            switch suffix {
            case "sage": return Palette.sage
            case "pink": return Palette.pink
            case "violet": return Palette.violet
            case "blue": return Palette.blue
            case "ochre": return Palette.ochre
            default: break
            }
        }
        return switch kind {
        case "cap", "badge": Palette.sage
        case "beanie", "star": Palette.clay
        case "pocket", "headband": Palette.violet
        case "goggles", "earmuffs": Palette.blue
        case "bow", "scarf": Palette.pink
        default: Palette.ochre
        }
    }

    var body: some View {
        Canvas { context, size in
            var context = context
            let factor = min(size.width, size.height) / 88
            context.translateBy(x: (size.width - 88 * factor) / 2, y: (size.height - 88 * factor) / 2)
            context.scaleBy(x: factor, y: factor)
            let art = Art(context: context)
            art.line([pt(33, 71), pt(32, 81), pt(37, 81)])
            art.line([pt(53, 71), pt(54, 81), pt(59, 81)])
            switch kind {
            case "cap", "visor", "badge":
                art.block(19, 18, 50, 56, radius: 13, fill: tint)
            case "beanie", "glasses":
                art.oval(16, 19, 56, 55, fill: tint)
            case "pocket", "scarf":
                art.poly([pt(29, 22), pt(59, 22), pt(74, 71), pt(14, 71)], fill: tint)
            case "goggles", "star":
                art.poly([pt(44, 11), pt(78, 44), pt(44, 76), pt(10, 44)], fill: tint)
            case "bow":
                art.poly([pt(45, 15), pt(73, 36), pt(62, 72), pt(26, 72), pt(15, 37)], fill: tint)
            default:
                art.block(24, 17, 40, 57, radius: 20, fill: tint)
            }
            switch kind {
            case "cap":
                art.block(28, 9, 28, 12, radius: 5, fill: tint)
                art.block(50, 16, 16, 5, radius: 2, fill: tint)
            case "beanie":
                art.block(50, 18, 23, 8, radius: 3, fill: Palette.paper)
                art.oval(52, 9, 18, 12, fill: tint)
                art.oval(61, 4, 9, 9, fill: Palette.paper)
            case "pocket":
                art.block(53, 55, 13, 10, radius: 3, fill: Palette.paper)
            case "goggles":
                art.block(12, 38, 64, 6, radius: 3, fill: Palette.paper)
                art.block(22, 34, 44, 16, radius: 5, fill: Palette.paper)
            case "earmuffs":
                var arc = Path()
                arc.addArc(center: pt(44, 36), radius: 25, startAngle: .degrees(180), endAngle: .degrees(360), clockwise: false)
                context.stroke(arc, with: .color(Palette.ink), lineWidth: 3)
                art.block(14, 34, 12, 21, radius: 5, fill: Palette.ochre)
                art.block(62, 34, 12, 21, radius: 5, fill: Palette.ochre)
            case "bow":
                art.poly([pt(47, 18), pt(53, 8), pt(61, 17), pt(73, 13), pt(73, 24), pt(60, 21)], fill: Palette.paper)
            case "visor":
                art.block(24, 12, 43, 8, radius: 4, fill: Palette.paper)
            case "scarf":
                art.line([pt(25, 33), pt(65, 33), pt(67, 40)], color: Palette.clay, width: 5)
            case "glasses":
                art.oval(26, 35, 15, 15, fill: Palette.paper, width: 1.5)
                art.oval(47, 35, 15, 15, fill: Palette.paper, width: 1.5)
                art.line([pt(41, 41), pt(47, 41)], width: 1.6)
            case "badge":
                art.oval(51, 54, 12, 12, fill: Palette.ochre, width: 1.5)
            case "star":
                art.poly([pt(59, 53), pt(61, 59), pt(67, 59), pt(61, 62), pt(59, 67),
                          pt(57, 62), pt(52, 59), pt(57, 58)], fill: Palette.paper, width: 1.2)
            default:
                art.block(24, 28, 40, 7, radius: 3, fill: Palette.paper)
            }
            art.oval(32, 40, 4, 4, fill: Palette.ink, width: 0)
            art.oval(52, 40, 4, 4, fill: Palette.ink, width: 0)
            art.line([pt(42, 49), pt(47, 49)], width: 2)
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityHidden(true)
    }
}

extension Station {
    var tint: Color {
        switch self {
        case .large: Palette.sage
        case .medium: Palette.clay
        case .small: Palette.violet
        case .sort: Palette.blue
        case .seal: Palette.ochre
        case .label: Palette.blue.opacity(0.74)
        }
    }
}

struct MachineArt: View {
    let station: Station

    var body: some View {
        Canvas { context, size in
            var context = context
            let factor = min(size.width / 124, size.height / 100)
            context.translateBy(x: (size.width - 124 * factor) / 2, y: (size.height - 100 * factor) / 2)
            context.scaleBy(x: factor, y: factor)
            let art = Art(context: context)
            let metal = station.tint
            switch station {
            case .large:
                art.block(48, 5, 25, 14, radius: 3, fill: metal)
                art.block(26, 18, 70, 65, radius: 5, fill: metal)
                art.block(37, 33, 42, 42, radius: 3, fill: Palette.paper)
                art.block(53, 35, 11, 17, radius: 2, fill: metal, width: 1.6)
                art.block(46, 51, 26, 7, radius: 2, fill: metal, width: 1.6)
                art.block(44, 68, 29, 5, radius: 1, fill: Palette.violet, width: 1.4)
                art.oval(83, 36, 8, 8, fill: Palette.paper, width: 1.4)
                art.line([pt(87, 40), pt(89, 38)], width: 1.3)
            case .medium:
                art.block(26, 56, 7, 28, radius: 2, fill: metal)
                art.block(92, 56, 7, 28, radius: 2, fill: metal)
                art.block(23, 48, 80, 14, radius: 3, fill: metal)
                art.block(29, 32, 21, 15, radius: 3, fill: Palette.paper, width: 1.6)
                art.line([pt(35, 38), pt(45, 38)], width: 1.4)
                art.oval(54, 35, 37, 12, fill: Palette.paper, width: 1.6)
                art.block(65, 28, 14, 10, radius: 2, fill: metal, width: 1.6)
                art.line([pt(95, 29), pt(107, 20), pt(109, 32)], color: Palette.quiet, width: 1.75)
            case .small:
                art.block(23, 44, 79, 40, radius: 5, fill: metal)
                art.block(42, 22, 43, 23, radius: 6, fill: Palette.paper)
                art.oval(75, 22, 12, 23, fill: metal, width: 1.6)
                art.oval(79, 30, 4, 7, fill: Palette.paper, width: 1.2)
                art.poly([pt(46, 40), pt(77, 40), pt(71, 65), pt(42, 65)], fill: Palette.paper, width: 1.6)
                art.block(42, 68, 33, 7, radius: 2, fill: Palette.beige, width: 1.4)
            case .sort:
                art.poly([pt(25, 30), pt(105, 30), pt(98, 62), pt(18, 62)], fill: metal)
                for x in [38.0, 63, 88] {
                    art.line([pt(x, 36), pt(x - 5, 55)], color: Palette.quiet, width: 1.6)
                }
                art.block(19, 62, 79, 16, radius: 3, fill: metal)
                for x in [29.0, 55, 81] { art.block(x, 68, 8, 4, radius: 1, fill: Palette.paper, width: 0) }
                art.block(24, 78, 8, 6, radius: 2, fill: metal)
                art.block(86, 78, 8, 6, radius: 2, fill: metal)
            case .seal:
                art.block(28, 36, 9, 35, radius: 2, fill: Palette.beige)
                art.block(86, 36, 9, 35, radius: 2, fill: Palette.beige)
                art.block(21, 29, 82, 14, radius: 3, fill: metal)
                art.block(43, 57, 35, 13, radius: 2, fill: Palette.paper, width: 1.6)
                art.line([pt(53, 62), pt(69, 62)], color: Palette.quiet, width: 1.3)
                art.block(18, 71, 88, 13, radius: 4, fill: metal)
                art.oval(91, 75, 5, 5, fill: Palette.paper, width: 1.1)
            case .label:
                art.block(27, 66, 25, 18, radius: 4, fill: metal)
                art.oval(21, 24, 43, 43, fill: metal)
                art.oval(35, 39, 13, 13, fill: Palette.paper, width: 1.6)
                art.line([pt(59, 53), pt(73, 56), pt(81, 69)], color: Palette.quiet, width: 1.6)
                art.block(74, 63, 29, 21, radius: 2, fill: Palette.clay)
                art.block(83, 68, 13, 7, radius: 1, fill: Palette.paper, width: 0)
            }
            art.block(14, 84, 96, 7, radius: 2, fill: Palette.beige, width: 1.65)
        }.accessibilityHidden(true)
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
