import 'package:flutter/material.dart';

class ScheduleScreen extends StatelessWidget {
  const ScheduleScreen({super.key});

  @override
  Widget build(BuildContext context) {

    // 🔹 Dummy data (baad me Firebase se connect kar sakti ho)
    List<Map<String, String>> meetings = [
      {
        "title": "Team Sync Meeting",
        "date": "25 April 2026",
        "time": "10:00 AM"
      },
      {
        "title": "Client Discussion",
        "date": "26 April 2026",
        "time": "2:30 PM"
      }
    ];

    return Scaffold(
      backgroundColor: Color(0xFFF4F6F8),

      // ===== HEADER =====
      appBar: AppBar(
        backgroundColor: Color(0xFF39A935),
        title: Text("Schedule"),
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),

      // ===== BODY =====
      body: meetings.isEmpty
          ? _emptyState()
          : ListView.builder(
              padding: EdgeInsets.all(16),
              itemCount: meetings.length,
              itemBuilder: (context, index) {

                final item = meetings[index];

                return Container(
                  margin: EdgeInsets.only(bottom: 14),
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(color: Colors.black12, blurRadius: 4)
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [

                      // TITLE
                      Text(
                        item['title']!,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      SizedBox(height: 8),

                      // DATE + TIME
                      Row(
                        children: [
                          Icon(Icons.calendar_today,
                              size: 16, color: Colors.grey),
                          SizedBox(width: 6),
                          Text(item['date']!,
                              style: TextStyle(color: Colors.grey)),

                          SizedBox(width: 12),

                          Icon(Icons.access_time,
                              size: 16, color: Colors.grey),
                          SizedBox(width: 6),
                          Text(item['time']!,
                              style: TextStyle(color: Colors.grey)),
                        ],
                      ),

                      SizedBox(height: 10),

                      // ACTION BUTTONS
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [

                          TextButton(
                            onPressed: () {},
                            child: Text("Edit",
                                style: TextStyle(color: Colors.blue)),
                          ),

                          TextButton(
                            onPressed: () {},
                            child: Text("Delete",
                                style: TextStyle(color: Colors.red)),
                          ),
                        ],
                      )
                    ],
                  ),
                );
              },
            ),

      // ===== ADD BUTTON =====
      floatingActionButton: FloatingActionButton(
        backgroundColor: Color(0xFF39A935),
        onPressed: () {
          // future: add meeting
        },
        child: Icon(Icons.add),
      ),
    );
  }

  // ===== EMPTY STATE =====
  Widget _emptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [

          Icon(Icons.schedule, size: 80, color: Colors.grey.shade400),

          SizedBox(height: 10),

          Text(
            "No Meetings Scheduled",
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF444444),
            ),
          ),

          SizedBox(height: 4),

          Padding(
            padding: EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              "Your upcoming meetings will appear here.",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFF777777),
              ),
            ),
          )
        ],
      ),
    );
  }
}