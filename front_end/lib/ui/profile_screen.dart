/*import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {

  String name = '';
  String email = '';
  String language = 'English';
  bool loading = true;

  final List<String> languages = [
    "English",
    "Urdu",
    "Arabic",
    "Hindi",
  ];

  // ===== FETCH USER =====
  @override
  void initState() {
    super.initState();
    fetchUser();
  }

  Future<void> fetchUser() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final docSnap = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (docSnap.exists) {
        final data = docSnap.data()!;
        setState(() {
          name = data['name'] ?? '';
          email = data['email'] ?? '';
          language = data['preferredLanguage'] ?? 'English';
        });
      }
    } catch (e) {
      print(e);
    } finally {
      setState(() => loading = false);
    }
  }

  // ===== CHANGE LANGUAGE =====
  Future<void> changeLanguage(String lang) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() {
      language = lang;
    });

    Navigator.pop(context);

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({
        'preferredLanguage': lang
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Language updated to $lang")),
      );
    } catch (e) {
      print(e);
    }
  }

  // ===== LOADING =====
  @override
  Widget build(BuildContext context) {

    if (loading) {
      return Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF39A935)),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Color(0xFFF4F6F8),

      // ===== HEADER =====
      appBar: AppBar(
        backgroundColor: Color(0xFF39A935),
        title: Text("Profile"),
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),

      body: Column(
        children: [

          // ===== PROFILE CARD =====
          Container(
            margin: EdgeInsets.all(20),
            padding: EdgeInsets.all(25),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(color: Colors.black12, blurRadius: 4)
              ],
            ),
            child: Column(
              children: [

                Icon(Icons.account_circle,
                    size: 95, color: Color(0xFF39A935)),

                SizedBox(height: 10),

                Text(name,
                    style:
                        TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),

                Text(email, style: TextStyle(color: Colors.grey)),

                SizedBox(height: 20),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("Preferred Language",
                        style: TextStyle(fontWeight: FontWeight.w600)),
                    Text(language,
                        style: TextStyle(
                            color: Color(0xFF39A935),
                            fontWeight: FontWeight.w600)),
                  ],
                )
              ],
            ),
          ),

          // ===== CHANGE LANGUAGE =====
          GestureDetector(
            onTap: () {
              showModalBottomSheet(
                context: context,
                shape: RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.vertical(top: Radius.circular(15)),
                ),
                builder: (_) {
                  return Container(
                    padding: EdgeInsets.all(20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [

                        Text("Select Language",
                            style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold)),

                        SizedBox(height: 10),

                        ...languages.map((lang) => ListTile(
                              title: Text(lang),
                              onTap: () => changeLanguage(lang),
                            )),

                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: Text("Cancel",
                              style: TextStyle(color: Colors.red)),
                        )
                      ],
                    ),
                  );
                },
              );
            },
            child: Container(
              margin: EdgeInsets.symmetric(horizontal: 20),
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Color(0xFFE8F7E6),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  "Change Language",
                  style: TextStyle(
                      color: Color(0xFF39A935),
                      fontWeight: FontWeight.bold,
                      fontSize: 16),
                ),
              ),
            ),
          ),

          SizedBox(height: 20),

          // ===== LOGOUT =====
          GestureDetector(
            onTap: () async {
              await FirebaseAuth.instance.signOut();
              Navigator.pushReplacementNamed(context, '/login');
            },
            child: Container(
              margin: EdgeInsets.symmetric(horizontal: 20),
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Color(0xFF39A935),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  "Logout",
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16),
                ),
              ),
            ),
          )
        ],
      ),
    );
  }
}*/




import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String name = '';
  String email = '';
  String language = '';
  bool loading = true;

  final List<String> languages = [
    "English",
    "Urdu",
    "Arabic",
    "Hindi",
  ];

  @override
  void initState() {
    super.initState();
    fetchUser();
  }

  // ===== FETCH USER =====
  Future<void> fetchUser() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final docSnap = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (docSnap.exists) {
        final data = docSnap.data()!;
        setState(() {
          name = data['name'] ?? '';
          email = data['email'] ?? '';
          language = data['preferredLanguage'] ?? '';
        });
      }
    } catch (e) {
      print(e);
    } finally {
      setState(() => loading = false);
    }
  }

  // ===== CHANGE LANGUAGE =====
  Future<void> changeLanguage(String lang) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() {
      language = lang;
    });

    Navigator.pop(context);

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set({
        'preferredLanguage': lang,
      }, SetOptions(merge: true));

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Language updated to $lang")),
      );
    } catch (e) {
      print(e);
    }
  }

  // ===== VALIDATION BEFORE MEETING =====
  void checkLanguageBeforeMeeting() {
    if (language.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("⚠ Please select your language first")),
      );
    } else {
      // yahan tum meeting create/join screen call kar sakti ho
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("✅ Ready for meeting in $language")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF39A935)),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Color(0xFFF4F6F8),

      appBar: AppBar(
        backgroundColor: Color(0xFF39A935),
        title: Text("Profile"),
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),

      // ✅ FIX OVERFLOW → SingleChildScrollView
      body: SingleChildScrollView(
        child: Column(
          children: [

            // ===== PROFILE CARD =====
            Container(
              margin: EdgeInsets.all(20),
              padding: EdgeInsets.all(25),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(color: Colors.black12, blurRadius: 4)
                ],
              ),
              child: Column(
                children: [
                  Icon(Icons.account_circle,
                      size: 95, color: Color(0xFF39A935)),

                  SizedBox(height: 10),

                  Text(name,
                      style: TextStyle(
                          fontSize: 20, fontWeight: FontWeight.bold)),

                  Text(email, style: TextStyle(color: Colors.grey)),

                  SizedBox(height: 20),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("Preferred Language",
                          style: TextStyle(fontWeight: FontWeight.w600)),

                      Text(
                        language.isEmpty ? "Not Selected" : language,
                        style: TextStyle(
                            color: Color(0xFF39A935),
                            fontWeight: FontWeight.w600),
                      ),
                    ],
                  )
                ],
              ),
            ),

            // ===== CHANGE LANGUAGE =====
            GestureDetector(
              onTap: () {
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true, // ✅ FIX OVERFLOW
                  shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(15)),
                  ),
                  builder: (_) {
                    return SafeArea(
                      child: Container(
                        padding: EdgeInsets.all(20),
                        child: SingleChildScrollView(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text("Select Language",
                                  style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold)),

                              SizedBox(height: 10),

                              ...languages.map((lang) => ListTile(
                                    title: Text(lang),
                                    onTap: () => changeLanguage(lang),
                                  )),

                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: Text("Cancel",
                                    style: TextStyle(color: Colors.red)),
                              )
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
              child: Container(
                margin: EdgeInsets.symmetric(horizontal: 20),
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Color(0xFFE8F7E6),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    "Change Language",
                    style: TextStyle(
                        color: Color(0xFF39A935),
                        fontWeight: FontWeight.bold,
                        fontSize: 16),
                  ),
                ),
              ),
            ),

            SizedBox(height: 20),

            // ===== CHECK BEFORE MEETING BUTTON =====
            GestureDetector(
              onTap: checkLanguageBeforeMeeting,
              child: Container(
                margin: EdgeInsets.symmetric(horizontal: 20),
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    "Continue to Meeting",
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16),
                  ),
                ),
              ),
            ),

            SizedBox(height: 20),

            // ===== LOGOUT =====
            GestureDetector(
              onTap: () async {
                await FirebaseAuth.instance.signOut();
                Navigator.pushReplacementNamed(context, '/login');
              },
              child: Container(
                margin: EdgeInsets.symmetric(horizontal: 20),
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Color(0xFF39A935),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    "Logout",
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16),
                  ),
                ),
              ),
            ),

            SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}