import 'dart:io';

import 'package:chat_app/data/models/chat_message.dart';
import 'package:chat_app/data/services/service_locator.dart';
import 'package:chat_app/logic/cubits/chat/chat_cubit.dart';
import 'package:chat_app/logic/cubits/chat/chat_state.dart';
import 'package:chat_app/presentation/widgets/loading_dots.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

class ChatMessageSceen extends StatefulWidget {
  final String receiverId;
  final String receiverName;
  final String currentUserName;
  const ChatMessageSceen({
    super.key,
    required this.receiverId,
    required this.receiverName,
    required this.currentUserName,
  });

  @override
  State<ChatMessageSceen> createState() => _ChatMessageSceenState();
}

class _ChatMessageSceenState extends State<ChatMessageSceen> {
  final TextEditingController messageController = TextEditingController();
  late final ChatCubit _chatCubit;
  final _scrollController = ScrollController();
  List<ChatMessage> _previousMessages = [];

  bool _isComposing = false;
  bool _showEmoji = false;

  @override
  void initState() {
    _chatCubit = getIt<ChatCubit>();
    _chatCubit.enterChat(widget.receiverId);
    messageController.addListener(_onTextChange);
    _scrollController.addListener(_onScroll);
    super.initState();
  }

  Future<void> _handleSendMessage() async {
    final messageText = messageController.text.trim();
    messageController.clear();
    await _chatCubit.sendMessage(
      content: messageText,
      receiverId: widget.receiverId,
    );
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _chatCubit.loadMoreMessage();
    }
  }

  void _onTextChange() {
    final isComposing = messageController.text.isNotEmpty;

    if (isComposing != _isComposing) {
      setState(() {
        _isComposing = isComposing;
      });
      if (isComposing) {
        _chatCubit.startTyping();
      }
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void _hasNewMessages(List<ChatMessage> messages) {
    if (messages.length != _previousMessages.length) {
      _scrollToBottom();
      _previousMessages = messages;
    }
  }

  @override
  void dispose() {
    messageController.dispose();
    _scrollController.dispose();
    _chatCubit.leaveChat();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            CircleAvatar(
              backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
              child: Text(widget.receiverName[0].toUpperCase()),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.receiverName),
                  BlocBuilder<ChatCubit, ChatState>(
                    bloc: _chatCubit,
                    builder: (context, state) {
                      if (state.isReceiverTyping) {
                        return Row(
                          children: [
                            Text(
                              "typing",
                              style: TextStyle(
                                color: Theme.of(context).primaryColor,
                              ),
                            ),
                            Container(
                              margin: EdgeInsets.only(right: 4),
                              child: LoadingDots(),
                            ),
                          ],
                        );
                      }
                      if (state.isReceiverOnline) {
                        return Text(
                          "Online",
                          style: TextStyle(color: Colors.green, fontSize: 14),
                        );
                      }
                      if (state.receiverLastSeen != null) {
                        final lastSeen = state.receiverLastSeen!.toDate();
                        return Text(
                          "last seen at ${DateFormat('h:mm a').format(lastSeen)}",
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                        );
                      }
                      return SizedBox();
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(onPressed: () {}, icon: Icon(Icons.video_call)),
          BlocBuilder<ChatCubit, ChatState>(
            bloc: _chatCubit,
            builder: (context, state) {
              if (state.isUserBlocked) {
                return TextButton.icon(
                  onPressed: () => _chatCubit.unBlockUser(widget.receiverId),
                  label: Text("Unblock"),
                  icon: Icon(Icons.block),
                );
              }
              return PopupMenuButton<String>(
                icon: Icon(Icons.more_vert),
                onSelected: (value) async {
                  if (value == "block") {
                    final bool? confirm = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: Text("Are you sure?"),
                        actions: [
                          TextButton(
                            onPressed: () {
                              Navigator.pop(context);
                            },
                            child: Text("Cancel"),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: Text(
                              "Block",
                              style: TextStyle(color: Colors.red),
                            ),
                          ),
                        ],
                      ),
                    );
                    if (confirm == true) {
                      await _chatCubit.blockUser(widget.receiverId);
                    }
                  }
                },
                itemBuilder: (context) => <PopupMenuEntry<String>>[
                  PopupMenuItem(value: "block", child: Text("Block")),
                ],
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: BlocConsumer<ChatCubit, ChatState>(
          listener: (context, state) {
            _hasNewMessages(state.messages);
          },
          bloc: _chatCubit,
          builder: (context, state) {
            if (state.status == ChatStatus.loading) {
              return Center(child: CircularProgressIndicator());
            }
            if (state.status == ChatStatus.error) {
              return Center(child: Text(state.error ?? "Something went wrong"));
            }
            return Column(
              children: [
                if (state.amIBlocked)
                  Container(
                    padding: EdgeInsets.all(8),
                    color: Colors.red.withOpacity(0.1),
                    child: Text(
                      "You have been blocked by ${widget.receiverName}",
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.red),
                    ),
                  ),
                Expanded(
                  child: ListView.builder(
                    controller: _scrollController,
                    reverse: true,
                    itemCount: state.messages.length,
                    itemBuilder: (context, index) {
                      final message = state.messages[index];
                      final isMe = message.senderId == _chatCubit.currentUserId;
                      return MessageBubble(message: message, isMe: isMe);
                    },
                  ),
                ),
                if (!state.amIBlocked && !state.isUserBlocked)
                  Padding(
                    padding: EdgeInsets.all(8),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            IconButton(
                              onPressed: () {
                                setState(() {
                                  _showEmoji = !_showEmoji;
                                  if (_showEmoji) {
                                    FocusScope.of(context).unfocus();
                                  }
                                });
                              },
                              icon: Icon(Icons.emoji_emotions_outlined),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextField(
                                onTap: () {
                                  if (_showEmoji) {
                                    _showEmoji = false;
                                  }
                                },
                                controller: messageController,
                                textCapitalization:
                                    TextCapitalization.sentences,
                                keyboardType: TextInputType.multiline,
                                decoration: InputDecoration(
                                  hintText: "Type a message...",
                                  filled: true,
                                  fillColor: Theme.of(context).cardColor,
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(24),
                                    borderSide: BorderSide.none,
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(width: 8),
                            IconButton(
                              icon: Icon(
                                Icons.send_outlined,
                                color: _isComposing
                                    ? Theme.of(context).primaryColor
                                    : Colors.grey,
                              ),
                              onPressed: _isComposing
                                  ? _handleSendMessage
                                  : null,
                            ),
                          ],
                        ),
                        if (_showEmoji)
                          SizedBox(
                            height: 250,
                            child: EmojiPicker(
                              textEditingController: messageController,
                              onEmojiSelected: (category, emoji) {
                                messageController
                                  ..text += emoji.emoji
                                  ..selection = TextSelection.fromPosition(
                                    TextPosition(
                                      offset: messageController.text.length,
                                    ),
                                  );
                                setState(() {
                                  _isComposing =
                                      messageController.text.isNotEmpty;
                                });
                              },
                              config: Config(
                                height: 250,
                                emojiViewConfig: EmojiViewConfig(
                                  columns: 7,
                                  emojiSizeMax:
                                      32.0 * (Platform.isIOS ? 1.30 : 1.0),
                                  verticalSpacing: 0,
                                  horizontalSpacing: 0,
                                  gridPadding: EdgeInsets.zero,
                                  backgroundColor: Theme.of(
                                    context,
                                  ).scaffoldBackgroundColor,
                                  loadingIndicator: const SizedBox.shrink(),
                                ),
                                categoryViewConfig: const CategoryViewConfig(
                                  initCategory: Category.RECENT,
                                ),
                                bottomActionBarConfig: BottomActionBarConfig(
                                  enabled: true,
                                  backgroundColor: Theme.of(
                                    context,
                                  ).scaffoldBackgroundColor,
                                  buttonColor: Theme.of(context).primaryColor,
                                ),
                                skinToneConfig: const SkinToneConfig(
                                  enabled: true,
                                  dialogBackgroundColor: Colors.white,
                                  indicatorColor: Colors.grey,
                                ),
                                searchViewConfig: SearchViewConfig(
                                  backgroundColor: Theme.of(
                                    context,
                                  ).scaffoldBackgroundColor,
                                  buttonIconColor: Theme.of(
                                    context,
                                  ).primaryColor,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isMe;

  const MessageBubble({super.key, required this.message, required this.isMe});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.only(
          left: isMe ? 64 : 8,
          right: isMe ? 8 : 64,
          bottom: 4,
        ),
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isMe
              ? Theme.of(context).primaryColor
              : Theme.of(context).primaryColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message.content,
              style: TextStyle(color: isMe ? Colors.white : Colors.black),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  DateFormat('h:mm a').format(message.timestamp.toDate()),
                  style: TextStyle(color: isMe ? Colors.white : Colors.black),
                ),
                if (isMe) ...[
                  Icon(
                    size: 14,
                    message.status == MessageStatus.read
                        ? Icons.done_all
                        : Icons.done,
                    color: message.status == MessageStatus.read
                        ? Colors.green
                        : Colors.white70,
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
