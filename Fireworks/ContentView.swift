//
//  ContentView.swift
//  Fireworks
//
//  Created by Ken Linsenmayer on 9/21/25.
//

import SwiftUI
import Combine

struct ContentView: View {
    @State private var isRunning = false
    @StateObject private var engine = FireworksEngine()

    var body: some View {
        ZStack {
            // Night sky background
            Color.black
                .ignoresSafeArea()

            // Fireworks canvas driven by a timeline
            TimelineView(.animation) { timeline in
                Canvas { context, size in
                    engine.step(date: timeline.date, size: size, running: isRunning)

                    // Additive blending for bright, colorful bursts
                    context.blendMode = .plusLighter

                    // Draw rockets
                    for rocket in engine.rockets {
                        let r: CGFloat = 3
                        let rect = CGRect(x: rocket.position.x - r, y: rocket.position.y - r, width: r * 2, height: r * 2)
                        var path = Path(ellipseIn: rect)
                        context.fill(path, with: .color(rocket.color))
                    }

                    // Draw particles
                    for p in engine.particles {
                        // Size and fade based on lifetime progress
                        let t = max(0, min(1, p.age / max(0.0001, p.lifetime)))
                        let radius = p.baseRadius * (1 - CGFloat(0.6 * t))
                        let alpha = Double((1 - t) * (1 - t)) // ease-out fade
                        let color = p.color.opacity(alpha)

                        let rect = CGRect(x: p.position.x - radius, y: p.position.y - radius, width: radius * 2, height: radius * 2)
                        var path = Path(ellipseIn: rect)
                        context.fill(path, with: .color(color))
                    }
                }
            }

            // Bottom control
            VStack {
                Spacer()
                Button(action: { isRunning.toggle() }) {
                    Text(isRunning ? "Stop" : "Start")
                        .font(.title2).bold()
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(Capsule().fill(isRunning ? Color.red : Color.green))
                        .foregroundStyle(.white)
                        .shadow(color: .white.opacity(0.2), radius: 10, x: 0, y: 0)
                }
                .padding(.bottom, 30)
            }
            .ignoresSafeArea(edges: .bottom)
        }
    }
}

// MARK: - Fireworks Engine

final class FireworksEngine: ObservableObject {
    // MARK: Rocket & Particle Models
    struct Rocket {
        var position: CGPoint
        var velocity: CGVector
        var color: Color
        var fuse: TimeInterval
    }

    struct Particle {
        var position: CGPoint
        var velocity: CGVector
        var color: Color
        var lifetime: TimeInterval
        var age: TimeInterval
        var drag: CGFloat
        var baseRadius: CGFloat
    }

    // MARK: State
    private(set) var rockets: [Rocket] = []
    private(set) var particles: [Particle] = []

    private var lastTime: TimeInterval?
    private var timeUntilNextLaunch: TimeInterval = 0

    // Physics constants (in points/second)
    private let gravity: CGFloat = 260 // downward acceleration

    func step(date: Date, size: CGSize, running: Bool) {
        let now = date.timeIntervalSinceReferenceDate
        let dt = max(0, min(1/30, (lastTime.map { now - $0 } ?? 0))) // clamp to avoid big jumps
        lastTime = now

        guard size.width > 0 && size.height > 0 else { return }

        // Launch rockets when running
        if running {
            timeUntilNextLaunch -= dt
            if timeUntilNextLaunch <= 0 {
                spawnRocket(in: size)
                // Randomize next launch time for variety
                timeUntilNextLaunch = Double.random(in: 0.18...0.6)
            }
        }

        // Update rockets
        var newRockets: [Rocket] = []
        newRockets.reserveCapacity(rockets.count)

        for var r in rockets {
            // Integrate physics
            r.velocity.dy += gravity * CGFloat(dt)
            r.position.x += r.velocity.dx * CGFloat(dt)
            r.position.y += r.velocity.dy * CGFloat(dt)
            r.fuse -= dt

            // Explode either at fuse end or when starting to fall
            if r.fuse <= 0 || r.velocity.dy > 0 {
                explode(rocket: r)
            } else {
                newRockets.append(r)
            }
        }
        rockets = newRockets

        // Update particles
        var newParticles: [Particle] = []
        newParticles.reserveCapacity(particles.count)
        for var p in particles {
            // Simple drag
            let dragFactor = max(0, 1 - p.drag * CGFloat(dt))
            p.velocity.dx *= dragFactor
            p.velocity.dy *= dragFactor

            // Gravity
            p.velocity.dy += gravity * CGFloat(dt) * CGFloat(0.6) // a bit lighter than rockets for a nice arc

            // Integrate position
            p.position.x += p.velocity.dx * CGFloat(dt)
            p.position.y += p.velocity.dy * CGFloat(dt)

            // Age
            p.age += dt

            // Keep if alive and on screen (with some slack)
            if p.age < p.lifetime,
               p.position.x > -60, p.position.x < size.width + 60,
               p.position.y > -60, p.position.y < size.height + 60 {
                newParticles.append(p)
            }
        }
        particles = newParticles
    }

    // MARK: Spawning
    private func spawnRocket(in size: CGSize) {
        let origin = CGPoint(x: size.width / 2, y: size.height)

        // Choose a random target region in the upper part of the screen
        let targetX = CGFloat.random(in: size.width * 0.1 ... size.width * 0.9)
        let targetY = CGFloat.random(in: size.height * 0.18 ... size.height * 0.45)
        let target = CGPoint(x: targetX, y: targetY)

        // Compute an initial velocity roughly toward target
        let dx = target.x - origin.x
        let dy = target.y - origin.y
        let distance = max(1, hypot(dx, dy))
        let dirX = dx / distance
        let dirY = dy / distance
        let speed = CGFloat.random(in: 520 ... 720)

        let rocketColor = randomBrightColor()

        let rocket = Rocket(
            position: origin,
            velocity: CGVector(dx: dirX * speed, dy: dirY * speed),
            color: rocketColor,
            fuse: TimeInterval.random(in: 0.9 ... 1.6)
        )
        rockets.append(rocket)
    }

    private func explode(rocket: Rocket) {
        // Number of particles per explosion
        let count = Int.random(in: 70 ... 130)
        let hueBase = Double.random(in: 0...1)

        for i in 0..<count {
            // Distribute directions around the circle with some randomness
            let angle = (Double(i) / Double(count)) * 2 * .pi + Double.random(in: -0.1...0.1)
            let speed = CGFloat.random(in: 120 ... 340)
            let vx = CGFloat(cos(angle)) * speed
            let vy = CGFloat(sin(angle)) * speed

            // Color variation around a base hue for cohesion
            let hue = (hueBase + Double.random(in: -0.05...0.05)).truncatingRemainder(dividingBy: 1)
            let color = Color(hue: hue < 0 ? hue + 1 : hue, saturation: 0.9, brightness: 1.0)

            let particle = Particle(
                position: rocket.position,
                velocity: CGVector(dx: vx, dy: vy),
                color: color,
                lifetime: TimeInterval.random(in: 1.6 ... 2.8),
                age: 0,
                drag: CGFloat.random(in: 0.2 ... 0.45),
                baseRadius: CGFloat.random(in: 2.2 ... 3.8)
            )
            particles.append(particle)
        }
    }

    // MARK: Utilities
    private func randomBrightColor() -> Color {
        Color(hue: Double.random(in: 0...1), saturation: 0.9, brightness: 1)
    }
}

#Preview {
    ContentView()
}
