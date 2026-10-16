import Foundation
import Testing
@testable import LifeCoachCore

struct PersonDetectionTests {
    /// Alias "meine Freundin" → Lisa is detected in "meine freundin mag rosen"
    /// (MEMORY.md, Vorstufe 2: knownPersonIsDetectedByAlias).
    @Test func knownPersonIsDetectedByAlias() {
        let lisa = Person(name: "Lisa", aliases: ["meine Freundin", "Schatz"])

        let detected = PersonDetection.detect("meine freundin mag rosen", in: [lisa])

        #expect(detected.count == 1)
        #expect(detected.first?.name == "Lisa")
    }

    /// Only confirmed aliases count — a suggestion that was never confirmed does not fire
    /// (MEMORY.md: unconfirmedAliasIsIgnored, Aliase werden nie still übernommen).
    @Test func unconfirmedAliasIsIgnored() {
        let lisa = Person(name: "Lisa", aliases: [])

        let detected = PersonDetection.detect("meine freundin mag rosen", in: [lisa])

        #expect(detected.isEmpty)
    }

    /// Plain names match too, in input order (complement to alias detection).
    @Test func personIsDetectedByName() {
        let lisa = Person(name: "Lisa")
        let tom = Person(name: "Tom")

        let detected = PersonDetection.detect("lisa und tom waren wandern", in: [lisa, tom])

        #expect(detected.map(\.name) == ["Lisa", "Tom"])
    }

    /// Confirming an alias (M2a-Banner) appends it, without duplicates (Groß/Klein egal).
    @Test func confirmingAliasAddsItToPerson() {
        let lisa = Person(name: "Lisa")

        lisa.confirm("meine Freundin")

        #expect(lisa.aliases == ["meine Freundin"])
        lisa.confirm("Meine Freundin")
        #expect(lisa.aliases == ["meine Freundin"]) // kein Duplikat
    }
}
