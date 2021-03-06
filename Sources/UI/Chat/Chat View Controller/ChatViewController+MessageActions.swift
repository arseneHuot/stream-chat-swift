//
//  ChatViewController+MessageActions.swift
//  StreamChat
//
//  Created by Alexey Bukhtin on 09/05/2019.
//  Copyright © 2019 Stream.io Inc. All rights reserved.
//

import UIKit
import StreamChatCore
import RxSwift

extension ChatViewController {
    typealias CopyAction = () -> Void
    
    /// Show message actions when long press on a message cell.
    public struct MessageAction: OptionSet {
        public let rawValue: Int
        
        /// Add reactions.
        public static let reactions = MessageAction(rawValue: 1 << 0)
        /// Reply to a message.
        public static let reply = MessageAction(rawValue: 1 << 1)
        /// Edit an own message.
        public static let edit = MessageAction(rawValue: 1 << 2)
        /// Mute a user of the message.
        public static let muteUser = MessageAction(rawValue: 1 << 3)
        /// Flag a message.
        public static let flagMessage = MessageAction(rawValue: 1 << 4)
        /// Flag a user of the message.
        public static let flagUser = MessageAction(rawValue: 1 << 5)
        /// Ban a user of the message.
        public static let banUser = MessageAction(rawValue: 1 << 6)
        /// Copy text or URL from the message.
        public static let copy = MessageAction(rawValue: 1 << 7)
        /// Delete own message.
        public static let delete = MessageAction(rawValue: 1 << 8)
        
        /// All message actions.
        public static let all: MessageAction = [.reactions,
                                                .reply,
                                                .edit,
                                                .muteUser,
                                                .flagMessage,
                                                .flagUser,
                                                .banUser,
                                                .copy,
                                                .delete]
        
        public init(rawValue: Int) {
            self.rawValue = rawValue
        }
    }
    
    public func defaultActionSheet(from cell: UITableViewCell, for message: Message, locationInView: CGPoint) -> UIAlertController? {
        guard let presenter = channelPresenter else {
            return nil
        }
        
        let alert = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        
        if messageActions.contains(.reactions), presenter.channel.config.reactionsEnabled {
            alert.addAction(.init(title: "Réactions", style: .default, handler: { [weak self] _ in
                self?.showReactions(from: cell, in: message, locationInView: locationInView)
            }))
        }
        
        if messageActions.contains(.reply), presenter.canReply {
            alert.addAction(.init(title: "Répondre", style: .default, handler: { [weak self] _ in
                self?.showReplies(parentMessage: message)
            }))
        }
        
        if messageActions.contains(.edit), message.canEdit {
            alert.addAction(.init(title: "Modifier", style: .default, handler: { [weak self] _ in
                self?.edit(message: message)
            }))
        }
        
        if messageActions.contains(.copy), let copyAction = copyAction(for: message) {
            alert.addAction(.init(title: "Copier", style: .default, handler: { _ in copyAction() }))
        }
        
        if !message.user.isCurrent {
            // Mute.
            if messageActions.contains(.muteUser), presenter.channel.config.mutesEnabled {
                if message.user.isMuted {
                    alert.addAction(.init(title: "Réactiver les notifications", style: .default, handler: { [weak self] _ in
                        self?.unmute(user: message.user)
                    }))
                } else {
                    alert.addAction(.init(title: "Mode silencieux", style: .default, handler: { [weak self] _ in
                        self?.mute(user: message.user)
                    }))
                }
            }
            
            if presenter.channel.config.flagsEnabled {
                // Flag a message.
                if messageActions.contains(.flagMessage) {
                    if message.isFlagged {
                        alert.addAction(.init(title: "Ne plus signaler le message", style: .default, handler: { [weak self] _ in
                            self?.unflag(message: message)
                        }))
                    } else {
                        alert.addAction(.init(title: "Signaler le message", style: .destructive, handler: { [weak self] _ in
                            self?.flag(message: message)
                        }))
                    }
                }
                
                // Flag a user.
                if messageActions.contains(.flagUser) {
                    if message.user.isFlagged {
                        alert.addAction(.init(title: "Ne plus signaler l'utilisateur", style: .default, handler: { [weak self] _ in
                            self?.unflag(user: message.user)
                        }))
                    } else {
                        alert.addAction(.init(title: "Signaler l'utilisateur", style: .destructive, handler: { [weak self] _ in
                            self?.flag(user: message.user)
                        }))
                    }
                }
            }
            
            if messageActions.contains(.banUser),
                let channelPresenter = channelPresenter,
                !channelPresenter.channel.isBanned(message.user) {
                alert.addAction(.init(title: "Bloquer", style: .destructive, handler: { [weak self] _ in
                    if let channelPresenter = self?.channelPresenter {
                        self?.ban(user: message.user, channel: channelPresenter.channel)
                    }
                }))
            }
        }
        
        if messageActions.contains(.delete), message.canDelete {
            alert.addAction(.init(title: "Supprimer", style: .destructive, handler: { [weak self] _ in
                self?.conformDeleting(message: message)
            }))
        }
        
        if alert.actions.isEmpty {
            return nil
        }
        
        alert.addAction(.init(title: "Annuler", style: .cancel, handler: { _ in }))
        
        if UIDevice.isPad, let popoverPresentationController = alert.popoverPresentationController {
            let cellPositionY = tableView.convert(cell.frame, to: UIScreen.main.coordinateSpace).minY + locationInView.y
            let isAtBottom = cellPositionY > CGFloat.screenHeight * 0.6
            popoverPresentationController.permittedArrowDirections = isAtBottom ? .down : .up
            popoverPresentationController.sourceView = cell
            popoverPresentationController.sourceRect = CGRect(x: locationInView.x,
                                                              y: locationInView.y + (isAtBottom ? -15 : 15),
                                                              width: 0,
                                                              height: 0)
        }
        
        return alert
    }
    
    private func edit(message: Message) {
        composerView.text = message.text
        channelPresenter?.editMessage = message
        composerView.isEditing = true
        composerView.textView.becomeFirstResponder()
        
        if let composerAddFileContainerView = composerAddFileContainerView {
            composerEditingContainerView.sendToBack(for: [composerAddFileContainerView, composerCommandsContainerView])
        } else {
            composerEditingContainerView.sendToBack(for: [composerCommandsContainerView])
        }
        
        composerEditingContainerView.animate(show: true)
    }
    
    private func copyAction(for message: Message) -> CopyAction? {
        let copyText: String = message.text.trimmingCharacters(in: .whitespacesAndNewlines)
        var copyURL: URL?
        
        if let first = message.attachments.first, let url = first.url {
            copyURL = url
        }
        
        if !copyText.isEmpty || copyURL != nil {
            return {
                if !copyText.isEmpty {
                    UIPasteboard.general.string = copyText
                } else if let url = copyURL {
                    UIPasteboard.general.url = url
                }
            }
        }
        
        return nil
    }
    
    private func conformDeleting(message: Message) {
        var text: String?
        
        if message.textOrArgs.isEmpty {
            if let attachment = message.attachments.first {
                text = attachment.title
            }
        } else {
            text = message.text.count > 100 ? String(message.text.prefix(100)) + "..." : message.text
        }
        
        let alert = UIAlertController(title: "Supprimer le message ?", message: text, preferredStyle: .alert)
        
        alert.addAction(.init(title: "Supprimer", style: .destructive, handler: { [weak self] _ in
            if let self = self {
                message.delete().subscribe().disposed(by: self.disposeBag)
            }
        }))
        
        alert.addAction(.init(title: "Annuler", style: .cancel, handler: { _ in }))
        
        present(alert, animated: true)
    }
    
    private func mute(user: User) {
        user.mute()
            .observeOn(MainScheduler.instance)
            .subscribe(onNext: { [weak self] _ in
                if let backgroundColor = self?.view.backgroundColor {
                    self?.showBanner("Conversation avec @\(user.name) en mode silencieux", backgroundColor: backgroundColor)
                }
            })
            .disposed(by: disposeBag)
    }
    
    private func unmute(user: User) {
        user.unmute()
            .observeOn(MainScheduler.instance)
            .subscribe(onNext: { [weak self] _ in
                if let backgroundColor = self?.view.backgroundColor {
                    self?.showBanner("Réactivation des notifications dans la conversation avec @\(user.name)", backgroundColor: backgroundColor)
                }
            })
            .disposed(by: disposeBag)
    }
    
    private func flag(message: Message) {
        message.flag()
            .observeOn(MainScheduler.instance)
            .subscribe(onNext: { [weak self] _ in
                if let backgroundColor = self?.view.backgroundColor {
                    self?.showBanner("🚩 Signalé: \(message.textOrArgs)", backgroundColor: backgroundColor)
                }
            })
            .disposed(by: disposeBag)
    }
    
    private func unflag(message: Message) {
        message.unflag()
            .observeOn(MainScheduler.instance)
            .subscribe(onNext: { [weak self] _ in
                if let backgroundColor = self?.view.backgroundColor {
                    self?.showBanner("🚩 Désignalé: \(message.textOrArgs)", backgroundColor: backgroundColor)
                }
            })
            .disposed(by: disposeBag)
    }
    
    private func flag(user: User) {
        user.flag()
            .observeOn(MainScheduler.instance)
            .subscribe(onNext: { [weak self] _ in
                if let backgroundColor = self?.view.backgroundColor {
                    self?.showBanner("🚩 Signalé: \(user.name)", backgroundColor: backgroundColor)
                }
            })
            .disposed(by: disposeBag)
    }
    
    private func unflag(user: User) {
        user.unflag()
            .observeOn(MainScheduler.instance)
            .subscribe(onNext: { [weak self] _ in
                if let backgroundColor = self?.view.backgroundColor {
                    self?.showBanner("🚩 Désignalé: \(user.name)", backgroundColor: backgroundColor)
                }
            })
            .disposed(by: disposeBag)
    }
    
    private func ban(user: User, channel: Channel) {
        channel.ban(user: user)
            .observeOn(MainScheduler.instance)
            .subscribe(onNext: { [weak self] in
                if let backgroundColor = self?.view.backgroundColor {
                    self?.showBanner("🙅‍♀️ Bloqué: \(user.name)", backgroundColor: backgroundColor)
                }
            })
            .disposed(by: disposeBag)
    }
    
    private func unban(user: User, channel: Channel) {
        channel.unban(user: user)
            .observeOn(MainScheduler.instance)
            .subscribe(onNext: { [weak self] in
                if let backgroundColor = self?.view.backgroundColor {
                    self?.showBanner("🙅‍♀️ Débloqué: \(user.name)", backgroundColor: backgroundColor)
                }
            })
            .disposed(by: disposeBag)
    }
}

// MARK: - Context Menu

@available(iOS 13, *)
extension ChatViewController {
    
    public func tableView(_ tableView: UITableView,
                          contextMenuConfigurationForRowAt indexPath: IndexPath,
                          point: CGPoint) -> UIContextMenuConfiguration? {
        guard useContextMenuForActions else {
            return nil
        }
        
        return UIContextMenuConfiguration(identifier: nil, previewProvider: nil) { [weak self] _ in
            guard let self = self,
                let cell = tableView.cellForRow(at: indexPath),
                let message = self.channelPresenter?.items[indexPath.row].message else {
                return nil
            }
            
            let locationInView = tableView.convert(point, to: cell)
            return self.createActionsContextMenu(from: cell, for: message, locationInView: locationInView)
        }
    }
    
    public func defaultActionsContextMenu(from cell: UITableViewCell, for message: Message, locationInView: CGPoint) -> UIMenu? {
        guard let presenter = channelPresenter else {
            return nil
        }
        
        var actions = [UIAction]()
        
        if messageActions.contains(.reactions), presenter.channel.config.reactionsEnabled {
            actions.append(UIAction(title: "Réactions", image: UIImage(systemName: "smiley")) { [weak self] _ in
                self?.showReactions(from: cell, in: message, locationInView: locationInView)
            })
        }
        
        if messageActions.contains(.reply), presenter.canReply {
            actions.append(UIAction(title: "Répondre", image: UIImage(systemName: "arrowshape.turn.up.left")) { [weak self] _ in
                self?.showReplies(parentMessage: message)
            })
        }
        
        if messageActions.contains(.edit), message.canEdit {
            actions.append(UIAction(title: "Modifier", image: UIImage(systemName: "pencil")) { [weak self] _ in
                self?.edit(message: message)
            })
        }
        
        if messageActions.contains(.copy), let copyAction = copyAction(for: message) {
            actions.append(UIAction(title: "Copier", image: UIImage(systemName: "doc.on.doc")) { _ in copyAction() })
        }
        
        if !message.user.isCurrent {
            // Mute.
            if messageActions.contains(.muteUser), presenter.channel.config.mutesEnabled {
                if message.user.isMuted {
                    actions.append(UIAction(title: "Réactiver les notifications", image: UIImage(systemName: "speaker")) { [weak self] _ in
                        self?.unmute(user: message.user)
                    })
                } else {
                    actions.append(UIAction(title: "Mode silencieux", image: UIImage(systemName: "speaker.slash")) { [weak self] _ in
                        self?.mute(user: message.user)
                    })
                }
            }
            
            if presenter.channel.config.flagsEnabled {
                // Flag a message.
                if messageActions.contains(.flagMessage) {
                    if message.isFlagged {
                        actions.append(UIAction(title: "Ne plus signaler le message",
                                                image: UIImage(systemName: "flag.slash")) { [weak self] _ in
                            self?.unflag(message: message)
                        })
                    } else {
                        actions.append(UIAction(title: "Signaler le message",
                                                image: UIImage(systemName: "flag"),
                                                attributes: [.destructive]) { [weak self] _ in
                            self?.flag(message: message)
                        })
                    }
                }
                
                // Flag a user.
                if messageActions.contains(.flagUser) {
                    if message.user.isFlagged {
                        actions.append(UIAction(title: "Ne plus signaler l'utilisateur",
                                                image: UIImage(systemName: "hand.raised.slash")) { [weak self] _ in
                            self?.unflag(user: message.user)
                        })
                    } else {
                        actions.append(UIAction(title: "Signaler l'utilisateur",
                                                image: UIImage(systemName: "hand.raised"),
                                                attributes: [.destructive]) { [weak self] _ in
                            self?.flag(user: message.user)
                        })
                    }
                }
            }
            
            if messageActions.contains(.banUser),
                let channelPresenter = channelPresenter,
                !channelPresenter.channel.isBanned(message.user) {
                actions.append(UIAction(title: "Bloquer",
                                        image: UIImage(systemName: "exclamationmark.octagon"),
                                        attributes: [.destructive]) { [weak self] _ in
                    if let channelPresenter = self?.channelPresenter {
                        self?.ban(user: message.user, channel: channelPresenter.channel)
                    }
                })
            } else if messageActions.contains(.banUser),
               let channelPresenter = channelPresenter,
               channelPresenter.channel.isBanned(message.user) {
               actions.append(UIAction(title: "Débloquer",
                                       image: UIImage(systemName: "exclamationmark.octagon"),
                                       attributes: [.destructive]) { [weak self] _ in
                   if let channelPresenter = self?.channelPresenter {
                       self?.unban(user: message.user, channel: channelPresenter.channel)
                   }
               })
           }
        }
        
        if messageActions.contains(.delete), message.canDelete {
            actions.append(UIAction(title: "Supprimer",
                                    image: UIImage(systemName: "trash"),
                                    attributes: [.destructive]) { [weak self] _ in
                self?.conformDeleting(message: message)
            })
        }
        
        if actions.isEmpty {
            return nil
        }
        
        view.endEditing(true)
        
        return UIMenu(title: "", children: actions)
    }
}
