import SwiftUI

struct ContentView: View {
    @StateObject private var engine = FireworksEngine()
    @State private var isRunning = false

    var body: some View {
        GeometryReader { geometry in
            TimelineView(.animation) { timeline in
                Canvas { context, size in
                    engine.step(time: timeline.date, in: CGRect(origin: .zero, size: size))

                    context.blendMode = .plusLighter

                    for rocket in engine.rockets {
                        var rocketContext = context
                        let rect = CGRect(x: rocket.position.x - 2, y: rocket.position.y - 10, width: 4, height: 20)
                        rocketContext.fill(
                            Path(ellipseIn: rect),
                            with: .color(.white)
                        )
                    }

                    for particle in engine.particles {
                        var particleContext = context
                        let rect = CGRect(x: particle.position.x - particle.radius, y: particle.position.y - particle.radius, width: particle.radius * 2, height: particle.radius * 2)

                        particleContext.opacity = particle.opacity
                        particleContext.fill(
                            Path(ellipseIn: rect),
                            with: .color(particle.color)
                        )
                    }
                }
                .background(Color.black)
                .onAppear {
                    engine.reset(in: geometry.frame(in: .local))
                }
                .onChange(of: geometry.size) { newSize in
                    engine.reset(in: CGRect(origin: .zero, size: newSize))
                }
            }

            VStack {
                Spacer()
                Button(isRunning ? "Stop" : "Start") {
                    isRunning.toggle()
                    if isRunning {
                        engine.start()
                    } else {
                        engine.stop()
                    }
                }
                .font(.title2)
                .padding()
                .background(.white.opacity(0.1))
                .clipShape(Capsule())
                .padding(.bottom)
            }
        }
        .ignoresSafeArea()
    }
}

@MainActor
final class FireworksEngine: ObservableObject {
    struct Rocket: Identifiable {
        let id = UUID()
        var position: CGPoint
        var velocity: CGVector
        var exploded = false
    }

    struct Particle: Identifiable {
        let id = UUID()
        var position: CGPoint
        var velocity: CGVector
        var color: Color
        var radius: CGFloat
        var lifetime: TimeInterval
        var createdAt: Date

        var age: TimeInterval {
            Date().timeIntervalSince(createdAt)
        }

        var opacity: Double {
            max(0, 1 - age / lifetime)
        }
    }

    @Published private(set) var rockets: [Rocket] = []
    @Published private(set) var particles: [Particle] = []

    private var lastUpdate: Date = .distantPast
    private var launchTimer: TimeInterval = 0
    private var nextLaunchInterval: TimeInterval = 0

    private var bounds: CGRect = .zero
    private var isRunning = false

    // Constants
    private let gravity: CGFloat = 300
    private let drag: CGFloat = 0.9
    private let rocketSpeedRange: ClosedRange<CGFloat> = 400 ... 600
    private let rocketLaunchIntervalRange: ClosedRange<TimeInterval> = 0.15 ... 0.3

    func reset(in rect: CGRect) {
        bounds = rect
        rockets.removeAll()
        particles.removeAll()
        lastUpdate = .distantPast
        launchTimer = 0
        nextLaunchInterval = TimeInterval.random(in: rocketLaunchIntervalRange)
    }

    func start() {
        isRunning = true
    }

    func stop() {
        isRunning = false
    }

    func step(time: Date, in rect: CGRect) {
        if lastUpdate == .distantPast {
            lastUpdate = time
            return
        }

        let dt = min(time.timeIntervalSince(lastUpdate), 1/30)
        lastUpdate = time
        bounds = rect

        guard isRunning else { return }

        // Launch rockets at intervals
        launchTimer += dt
        if launchTimer > nextLaunchInterval {
            launchTimer = 0
            nextLaunchInterval = TimeInterval.random(in: rocketLaunchIntervalRange)
            launchRocket()
        }

        // Update rockets
        var newRockets: [Rocket] = []
        for var rocket in rockets {
            // Update position and velocity
            rocket.velocity.dy += gravity * CGFloat(dt)
            rocket.velocity.dx *= drag
            rocket.velocity.dy *= drag
            rocket.position.x += rocket.velocity.dx * CGFloat(dt)
            rocket.position.y += rocket.velocity.dy * CGFloat(dt)

            // Explode if velocity downward or reached near top quarter
            if !rocket.exploded && (rocket.velocity.dy > 0 || rocket.position.y < bounds.height * 0.25) {
                explode(rocket: rocket)
                rocket.exploded = true
            }

            // Keep rockets that have not exploded and are within bounds
            if !rocket.exploded && bounds.contains(rocket.position) {
                newRockets.append(rocket)
            }
        }
        rockets = newRockets

        // Update particles
        var newParticles: [Particle] = []
        for var particle in particles {
            particle.velocity.dy += gravity * CGFloat(dt) * 0.3
            particle.velocity.dx *= drag
            particle.velocity.dy *= drag

            particle.position.x += particle.velocity.dx * CGFloat(dt)
            particle.position.y += particle.velocity.dy * CGFloat(dt)

            if particle.opacity > 0 && bounds.insetBy(dx: -50, dy: -50).contains(particle.position) {
                newParticles.append(particle)
            }
        }
        particles = newParticles
    }

    private func launchRocket() {
        let x = CGFloat.random(in: bounds.width * 0.1 ... bounds.width * 0.9)
        let y = bounds.height
        let position = CGPoint(x: x, y: y)

        let targetX = CGFloat.random(in: bounds.width * 0.2 ... bounds.width * 0.8)
        let targetY = CGFloat.random(in: bounds.height * 0.05 ... bounds.height * 0.3)
        let target = CGPoint(x: targetX, y: targetY)

        let dx = target.x - position.x
        let dy = target.y - position.y
        let length = sqrt(dx*dx + dy*dy)
        let speed = CGFloat.random(in: rocketSpeedRange)
        let velocity = CGVector(dx: dx / length * speed, dy: dy / length * speed)

        let rocket = Rocket(position: position, velocity: velocity)
        rockets.append(rocket)
    }

    private func explode(rocket: Rocket) {
        let count = Int.random(in: 70 ... 130)
        let baseHue = Double.random(in: 0 ... 1)

        for _ in 0..<count {
            let angle = Double.random(in: 0 ... 2 * .pi)
            let speed = Double.random(in: 100 ... 400)
            let velocity = CGVector(dx: cos(angle) * speed, dy: sin(angle) * speed)

            let radius = CGFloat.random(in: 2 ... 5)
            let lifetime = TimeInterval.random(in: 1 ... 2)

            let hue = baseHue + Double.random(in: -0.05 ... 0.05)
            let color = Color(hue: hue.truncatingRemainder(dividingBy: 1), saturation: 1, brightness: 1)

            let particle = Particle(
                position: rocket.position,
                velocity: velocity,
                color: color,
                radius: radius,
                lifetime: lifetime,
                createdAt: Date()
            )
            particles.append(particle)
        }
    }
}

@main
struct FireworksApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
