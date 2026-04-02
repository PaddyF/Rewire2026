import SwiftUI
import SwiftData

struct ArtistDetailView: View {
    let slot: Slot

    @EnvironmentObject var store: ArtistStore
    @Environment(\.modelContext) private var modelContext
    @Query private var allUserData: [UserArtistData]
    @State private var notesText = ""
    @FocusState private var notesFocused: Bool

    private var participants: [Artist] {
        slot.artistIds.compactMap { store.lineup.artists[$0] }
    }

    private var userData: UserArtistData? {
        allUserData.first { $0.artistId == slot.id }
    }

    private func getOrCreate() -> UserArtistData {
        if let existing = userData { return existing }
        let new = UserArtistData(artistId: slot.id)
        modelContext.insert(new)
        return new
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {

                // ── Header card ─────────────────────────────────────
                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .top) {
                        HStack(spacing: 6) {
                            WaveBadge(wave: slot.wave)
                            if slot.isWorldPremiere { WorldPremiereBadge() }
                            if let type = slot.performanceType { TypeBadge(type: type) }
                            if slot.requiresPlusTicket {
                                Image(systemName: "ticket")
                                    .font(.system(size: 10))
                                    .foregroundStyle(Color.rewireTertiary)
                            }
                        }
                        Spacer()
                        Button {
                            let data = getOrCreate()
                            data.isBookmarked.toggle()
                        } label: {
                            Image(systemName: userData?.isBookmarked == true ? "bookmark.fill" : "bookmark")
                                .font(.system(size: 22))
                                .foregroundStyle(userData?.isBookmarked == true ? Color.rewireAccent : Color.rewireMuted)
                        }
                        .buttonStyle(.plain)
                    }

                    Text(slot.displayName)
                        .font(.rewireTitle(24))
                        .foregroundStyle(Color.rewireText)

                    if let project = slot.project, !project.isEmpty {
                        Text(project)
                            .font(.rewireBody(13))
                            .foregroundStyle(Color.rewireMuted)
                    }
                }
                .padding(16)
                .cardStyle()

                // ── Must See Rating card ────────────────────────────
                VStack(alignment: .leading, spacing: 10) {
                    Text("MUST SEE").sectionHeader()
                    MustSeeRatingView(rating: userData?.mustSeeRating ?? 0) { newRating in
                        getOrCreate().mustSeeRating = newRating
                    }
                }
                .padding(16)
                .cardStyle()

                // ── Collab info ─────────────────────────────────────
                if slot.isCollab {
                    VStack(alignment: .leading, spacing: 12) {
                        if let notes = slot.collabNotes, !notes.isEmpty {
                            Text(notes)
                                .font(.system(size: 14))
                                .foregroundStyle(Color.rewireText)
                                .lineSpacing(5)
                        }
                        if let rel = slot.collabLatest {
                            ReleaseRow(label: "COLLAB LATEST", release: rel)
                        }
                        if let rel = slot.collabTopRated {
                            ReleaseRow(label: "COLLAB TOP RATED", release: rel)
                        }
                    }
                    .padding(16)
                    .cardStyle()
                }

                // ── Participants ────────────────────────────────────
                ForEach(Array(participants.enumerated()), id: \.offset) { _, artist in
                    ParticipantSection(artist: artist)
                }

                // ── Conflict Warning ────────────────────────────────
                let conflictingSlots = store.conflicts(for: slot, allUserData: allUserData)
                if !conflictingSlots.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 11))
                                .foregroundStyle(Color.rewireTertiary)
                            Text("SCHEDULE CONFLICT")
                                .font(.rewireData(10, weight: .bold))
                                .foregroundStyle(Color.rewireTertiary)
                        }
                        ForEach(conflictingSlots, id: \.id) { conflict in
                            HStack(spacing: 4) {
                                Text("•").foregroundStyle(Color.rewireTertiary)
                                Text(conflict.displayName)
                                if let t = conflict.formattedTime {
                                    Text("· \(t)").foregroundStyle(Color.rewireMuted)
                                }
                            }
                            .font(.rewireData(12))
                            .foregroundStyle(Color.rewireText)
                        }
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.rewireTertiary.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.rewireTertiary.opacity(0.4), lineWidth: 1))
                }

                // ── Plus Ticket Warning ─────────────────────────────
                if slot.requiresPlusTicket {
                    PlusTicketWarning()
                }

                // ── Timetable card ──────────────────────────────────
                if slot.day != nil || slot.time != nil || slot.stage != nil {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("SCHEDULE").sectionHeader()
                        HStack(spacing: 12) {
                            if let day = slot.day {
                                Label(day, systemImage: "calendar")
                            }
                            if let time = slot.formattedTime {
                                Label(time, systemImage: "clock")
                            }
                            if let stage = slot.stage {
                                Label(stage, systemImage: "mappin")
                            }
                        }
                        .font(.rewireData(13))
                        .foregroundStyle(Color.rewireText)
                    }
                    .padding(16)
                    .cardStyle()
                }

                // ── Personal Notes card ─────────────────────────────
                VStack(alignment: .leading, spacing: 8) {
                    Text("PERSONAL NOTES").sectionHeader()

                    TextEditor(text: $notesText)
                        .focused($notesFocused)
                        .scrollContentBackground(.hidden)
                        .background(Color.rewireSurface)
                        .foregroundStyle(Color.rewireText)
                        .font(.system(size: 14))
                        .frame(minHeight: 100)
                        .padding(10)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(notesFocused ? Color.rewireAccent : Color.rewireBorder, lineWidth: 1)
                        )
                        .onChange(of: notesText) { _, new in
                            let current = userData?.personalNotes ?? ""
                            if new != current { getOrCreate().personalNotes = new }
                        }

                    if notesFocused {
                        Button("Done") { notesFocused = false }
                            .font(.rewireData(12))
                            .foregroundStyle(Color.rewireAccent)
                    }
                }
                .padding(16)
                .cardStyle()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(Color.rewireBackground)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarBackground(Color.rewireSurface, for: .navigationBar)
        .onAppear { notesText = userData?.personalNotes ?? "" }
    }
}

// MARK: - Participant section (one artist's profile block)

private struct ParticipantSection: View {
    let artist: Artist

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Hero image with gradient overlay
            if let imageUrl = artist.imageUrl, let url = URL(string: imageUrl) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(maxWidth: .infinity)
                            .frame(height: 200)
                            .clipped()
                            .overlay(
                                LinearGradient(
                                    colors: [.clear, .clear, Color.rewireSurface],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                    case .empty:
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.rewireSurface)
                            .frame(height: 200)
                            .overlay(ProgressView().tint(Color.rewireMuted))
                    default:
                        EmptyView()
                    }
                }
            }

            VStack(alignment: .leading, spacing: 12) {
                Text(artist.name)
                    .font(.rewireTitle(15))
                    .foregroundStyle(Color.rewireText)

                if !artist.genreList.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(artist.genreList, id: \.self) { GenreTag(text: $0) }
                        }
                    }
                }

                if let notes = artist.notes, !notes.isEmpty {
                    Text(notes)
                        .font(.rewireBody(13))
                        .foregroundStyle(Color.rewireMuted)
                        .lineSpacing(4)
                }

                if artist.latest != nil || artist.topRated != nil {
                    VStack(alignment: .leading, spacing: 10) {
                        if let rel = artist.latest   { ReleaseRow(label: "LATEST",     release: rel) }
                        if let rel = artist.topRated { ReleaseRow(label: "TOP RATED",  release: rel) }
                    }
                }
            }
            .padding(16)
        }
        .cardStyle()
    }
}
