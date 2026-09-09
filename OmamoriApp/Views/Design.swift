import SwiftUI

enum ShrineTheme {
    static let paper = Color(red: 0.98, green: 0.96, blue: 0.91)
    static let ink = Color(red: 0.29, green: 0.23, blue: 0.22)
    static let vermilion = Color(red: 0.71, green: 0.30, blue: 0.28)
    static let muted = Color(red: 0.51, green: 0.44, blue: 0.39)
    static let wood = Color(red: 0.88, green: 0.72, blue: 0.49)
}

struct PrimaryButton: ButtonStyle {
    @Environment(\.isEnabled) var enabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.system(.body, design: .rounded, weight: .semibold))
            .frame(maxWidth: .infinity).padding(.vertical, 16)
            .foregroundStyle(.white)
            .background(ShrineTheme.vermilion.opacity(enabled ? (configuration.isPressed ? 0.7 : 1) : 0.4), in: RoundedRectangle(cornerRadius: 18))
    }
}
struct PaperCard<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        content.padding(20).frame(maxWidth: .infinity, alignment: .leading)
            .background(.white.opacity(0.7), in: RoundedRectangle(cornerRadius: 24))
    }
}
struct PageHeading: View {
    let eyebrow: String
    let title: String
    let subtitle: String
    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(eyebrow).font(.caption.weight(.semibold)).tracking(3).foregroundStyle(ShrineTheme.vermilion)
            Text(title).font(.system(size: 30, weight: .medium, design: .serif))
            if !subtitle.isEmpty { Text(subtitle).font(.subheadline).foregroundStyle(ShrineTheme.muted).lineSpacing(4) }
        }.frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 8)
    }
}

// Vector geometry stays crisp at every size, and is fully driven by the form state.
struct CharmSilhouette: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width, h = rect.height
        path.move(to: CGPoint(x: w * 0.23, y: 0))
        path.addLine(to: CGPoint(x: w * 0.77, y: 0))
        path.addQuadCurve(to: CGPoint(x: w, y: h * 0.16), control: CGPoint(x: w, y: h * 0.1))
        path.addLine(to: CGPoint(x: w, y: h * 0.91))
        path.addQuadCurve(to: CGPoint(x: w * 0.9, y: h), control: CGPoint(x: w, y: h))
        path.addLine(to: CGPoint(x: w * 0.1, y: h))
        path.addQuadCurve(to: CGPoint(x: 0, y: h * 0.91), control: CGPoint(x: 0, y: h))
        path.addLine(to: CGPoint(x: 0, y: h * 0.16))
        path.addQuadCurve(to: CGPoint(x: w * 0.23, y: 0), control: CGPoint(x: 0, y: h * 0.1))
        path.closeSubpath()
        return path
    }
}
struct CharmArtwork: View {
    var color: CharmColor = .coral
    var blessing: String = "応援守り"
    var width: CGFloat = 150
    var body: some View {
        ZStack(alignment: .top) {
            // The loop and mizuhiki-style knot are decorative; the full label is exposed to VoiceOver.
            Ellipse().stroke(ShrineTheme.ink.opacity(0.5), lineWidth: width * 0.019)
                .frame(width: width * 0.24, height: width * 0.42).offset(y: -width * 0.24)
            ZStack {
                CharmSilhouette().fill(LinearGradient(colors: [color.color.opacity(0.8), color.color, color.color.opacity(0.92)], startPoint: .topLeading, endPoint: .bottomTrailing))
                Canvas { context, size in
                    for x in stride(from: 0.0, to: size.width, by: 4) {
                        var p = Path(); p.move(to: CGPoint(x: x, y: 0)); p.addLine(to: CGPoint(x: x, y: size.height))
                        context.stroke(p, with: .color(.white.opacity(0.09)), lineWidth: 0.7)
                    }
                    for y in stride(from: 0.0, to: size.height, by: 5) {
                        var p = Path(); p.move(to: CGPoint(x: 0, y: y)); p.addLine(to: CGPoint(x: size.width, y: y))
                        context.stroke(p, with: .color(.black.opacity(0.04)), lineWidth: 0.7)
                    }
                }.clipShape(CharmSilhouette())
                CharmSilhouette().stroke(.white.opacity(0.5), style: StrokeStyle(lineWidth: 1, dash: [3, 3])).padding(width * 0.06)
                VStack(spacing: width * 0.09) {
                    Image(systemName: "sparkle").font(.system(size: width * 0.12))
                    Text(blessing.isEmpty ? "お守り" : blessing)
                        .font(.system(size: width * 0.145, weight: .medium, design: .serif))
                        .multilineTextAlignment(.center).lineSpacing(4)
                        .frame(width: width * 0.24).fixedSize(horizontal: false, vertical: true)
                        .minimumScaleFactor(0.5)
                    Image(systemName: "leaf").font(.system(size: width * 0.10))
                }.foregroundStyle(Color(red: 1, green: 0.94, blue: 0.75)).padding(.top, width * 0.18)
            }.frame(width: width, height: width * 1.45)
                .shadow(color: color.color.opacity(0.2), radius: 12, x: 0, y: 10)
            ZStack {
                Ellipse().stroke(.white.opacity(0.95), lineWidth: width * 0.023).frame(width: width * 0.25, height: width * 0.13).rotationEffect(.degrees(-35)).offset(x: -width * 0.1)
                Ellipse().stroke(.white.opacity(0.95), lineWidth: width * 0.023).frame(width: width * 0.25, height: width * 0.13).rotationEffect(.degrees(35)).offset(x: width * 0.1)
                Circle().fill(.white).frame(width: width * 0.06)
            }.offset(y: width * 0.10)
        }.frame(width: width, height: width * 1.48).padding(.top, width * 0.25)
            .accessibilityElement(children: .ignore).accessibilityLabel("\(color.name)の\(blessing)")
    }
}

struct EmaSilhouette: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: 0, y: rect.height * 0.23))
        p.addLine(to: CGPoint(x: rect.width / 2, y: 0))
        p.addLine(to: CGPoint(x: rect.width, y: rect.height * 0.23))
        p.addLine(to: CGPoint(x: rect.width, y: rect.height))
        p.addLine(to: CGPoint(x: 0, y: rect.height))
        p.closeSubpath()
        return p
    }
}
struct EmaArtwork: View {
    let goal: String
    let name: String
    var fulfilled = false
    var body: some View {
        ZStack {
            EmaSilhouette().fill(LinearGradient(colors: [Color(red: 0.94, green: 0.82, blue: 0.63), ShrineTheme.wood], startPoint: .topLeading, endPoint: .bottomTrailing))
                .shadow(color: ShrineTheme.wood.opacity(0.2), radius: 8, y: 7)
            Canvas { context, size in
                for y in stride(from: 14.0, to: size.height, by: 13) {
                    var p = Path(); p.move(to: CGPoint(x: 0, y: y))
                    p.addCurve(to: CGPoint(x: size.width, y: y + 4), control1: CGPoint(x: size.width * 0.3, y: y - 7), control2: CGPoint(x: size.width * 0.7, y: y + 8))
                    context.stroke(p, with: .color(.brown.opacity(0.09)), lineWidth: 1)
                }
            }.clipShape(EmaSilhouette())
            EmaSilhouette().stroke(.brown.opacity(0.22), lineWidth: 1).padding(8)
            VStack(spacing: 8) {
                Capsule().fill(ShrineTheme.vermilion).frame(width: 7, height: 24)
                Text(fulfilled ? "成 就" : "奉 納").font(.caption.weight(.bold)).foregroundStyle(ShrineTheme.vermilion)
                Text(goal.isEmpty ? "あなたの願いごと" : goal)
                    .font(.system(.title3, design: .serif, weight: .medium)).multilineTextAlignment(.center)
                    .lineSpacing(5).frame(maxWidth: .infinity, minHeight: 70)
                HStack { Spacer(); Text(name.isEmpty ? "お名前" : name).font(.subheadline) }
            }.padding(.horizontal, 30).padding(.top, 10).padding(.bottom, 20)
        }.fixedSize(horizontal: false, vertical: true)
            .accessibilityElement(children: .ignore).accessibilityLabel("\(name)の絵馬。\(goal)。\(fulfilled ? "叶った願い" : "挑戦中")")
    }
}
struct EmptyCollection: View {
    let title: String
    let message: String
    let symbol: String
    var body: some View {
        ContentUnavailableView(title, systemImage: symbol, description: Text(message))
            .foregroundStyle(ShrineTheme.muted).padding(.vertical, 30)
    }
}
