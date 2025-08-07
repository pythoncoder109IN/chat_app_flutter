import 'package:chat_app/data/repositories/auth_repository.dart';
import 'package:chat_app/data/repositories/chat_repository.dart';
import 'package:chat_app/data/repositories/contact_repository.dart';
import 'package:chat_app/data/services/service_locator.dart';
import 'package:chat_app/logic/cubits/auth/auth_cubit.dart';
import 'package:chat_app/presentation/chat/chat_message_sceen.dart';
import 'package:chat_app/presentation/screens/auth/login_screen.dart';
import 'package:chat_app/presentation/widgets/chat_list_tile.dart';
import 'package:chat_app/router/app_router.dart';
import 'package:flutter/material.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final ContactRepository _contactRepository;
  late final ChatRepository _chatRepository;
  late final String _currentUserId;

  @override
  void initState() {
    _contactRepository = getIt<ContactRepository>();
    _chatRepository = getIt<ChatRepository>();
    _currentUserId = getIt<AuthRepository>().currentuser?.uid ?? "";
    super.initState();
  }

  void _showContactsList(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Container(
          padding: EdgeInsets.all(16),
          child: Column(
            children: [
              Text(
                "Contacts",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              Expanded(
                child: FutureBuilder<List<Map<String, dynamic>>>(
                  future: _contactRepository.getRegisteredContacts(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Center(child: Text("Error: ${snapshot.error}"));
                    }

                    if (!snapshot.hasData) {
                      return Center(child: CircularProgressIndicator());
                    }

                    final contacts = snapshot.data!;
                    if (contacts.isEmpty) {
                      return Text("No contacts found");
                    }
                    return ListView.builder(
                      itemCount: contacts.length,
                      itemBuilder: (context, index) {
                        final contact = contacts[index];
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Theme.of(
                              context,
                            ).primaryColor.withOpacity(0.1),
                            child: Text(contact["name"][0].toUpperCase()),
                          ),
                          title: Text(contact["name"]),
                          onTap: () {
                            getIt<AppRouter>().push(
                              ChatMessageSceen(
                                receiverId: contact['id'],
                                receiverName: contact['name'],
                                currentUserName:
                                    getIt<AuthRepository>()
                                        .currentuser
                                        ?.displayName ??
                                    "You",
                              ),
                            );
                          },
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Chat"),
        actions: [
          InkWell(
            onTap: () async {
              await getIt<AuthCubit>().signOut();
              getIt<AppRouter>().pushAndRemoveUntil(LoginScreen());
            },
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Icon(Icons.logout),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: StreamBuilder(
          stream: _chatRepository.getChatRooms(_currentUserId),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              print(snapshot.error);
              return Center(child: Text("error:${snapshot.error}"));
            }
            if (!snapshot.hasData) {
              return Center(child: CircularProgressIndicator());
            }
            final chats = snapshot.data!;
            if (chats.isEmpty) {
              return Center(child: Text("No recent chats"));
            }
            return ListView.builder(
              itemCount: chats.length,
              itemBuilder: (content, index) {
                final chat = chats[index];
                return ChatListTile(
                  chat: chat,
                  currentUserId: _currentUserId,
                  onTap: () {
                    final otherUserId = chat.participants.firstWhere(
                      (id) => id != _currentUserId,
                    );
                    final otherUserName =
                        chat.participantsName![otherUserId] ?? "Unknown";
                    getIt<AppRouter>().push(
                      ChatMessageSceen(
                        receiverId: otherUserId,
                        receiverName: otherUserName,
                        currentUserName:
                            getIt<AuthRepository>().currentuser?.displayName ??
                            "You",
                      ),
                    );
                  },
                );
              },
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showContactsList(context),
        child: Icon(Icons.chat_bubble_outline, color: Colors.white),
        shape: CircleBorder(),
      ),
    );
  }
}
