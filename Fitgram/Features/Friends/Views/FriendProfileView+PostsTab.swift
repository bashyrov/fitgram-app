import SwiftUI

/// "Posty" tab — the person's posts with likes, or a lock when their
/// privacy settings hide them from this viewer.
extension FriendProfileView {
    @ViewBuilder
    func postsTab() -> some View {
        if let authorPosts {
            if authorPosts.isHidden {
                placeholder(
                    symbol: "lock.fill",
                    title: TL(
                        pl: "Posty tylko dla znajomych", en: "Posts are for friends only", uk: "Пости лише для друзів",
                        ru: "Посты только для друзей", es: "Publicaciones solo para amigos"),
                    subtitle: TL(
                        pl: "Gdy zaakceptuje zaproszenie, zobaczysz tu jej lub jego posty.",
                        en: "Once they accept your request, their posts show up here.",
                        uk: "Коли запит приймуть, тут з'являться пости.",
                        ru: "Когда заявку примут, здесь появятся посты.",
                        es: "Cuando acepte tu solicitud, verás aquí sus publicaciones.")
                )
            } else if authorPosts.posts.isEmpty {
                placeholder(
                    symbol: "text.bubble",
                    title: TL(
                        pl: "Brak postów", en: "No posts", uk: "Немає постів", ru: "Нет постов", es: "Sin publicaciones"
                    ),
                    subtitle: TL(
                        pl: "Ta osoba jeszcze niczego nie opublikowała.", en: "This person hasn't posted anything yet.",
                        uk: "Ця людина ще нічого не опублікувала.", ru: "Этот человек ещё ничего не опубликовал.",
                        es: "Esta persona aún no ha publicado nada.")
                )
            } else {
                LazyVStack(spacing: 10) {
                    ForEach(authorPosts.posts) { post in
                        PostCard(
                            post: post,
                            isMine: post.authorID == state.userRemoteID,
                            onLike: { Task { await toggleLike(post) } }
                        )
                    }
                }
            }
        } else {
            VStack(spacing: 10) {
                LoadingShimmer(cornerRadius: 24).frame(height: 160)
                LoadingShimmer(cornerRadius: 24).frame(height: 120)
            }
        }
    }

    private func toggleLike(_ post: SocialPost) async {
        guard let current = authorPosts, let index = current.posts.firstIndex(where: { $0.id == post.id }) else {
            return
        }
        let liked = !post.isLikedByMe
        var posts = current.posts
        posts[index].isLikedByMe = liked
        posts[index].likeCount = max(0, posts[index].likeCount + (liked ? 1 : -1))
        authorPosts = AuthorPosts(posts: posts, isHidden: false)
        if await !state.setLiked(liked, postID: post.id) {
            authorPosts = current
        }
    }
}
