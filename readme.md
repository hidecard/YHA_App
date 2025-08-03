# YHA App - Youth Health Academy

A comprehensive Flutter application for managing courses, posts, and student interactions.

## 🚀 Current Implemented Features

### ✅ **Authentication Module**
- Login / Register with Email authentication
- Forgot password functionality
- Firebase Authentication integration
- OTP verification system

### ✅ **Course & Class Module**
- View courses with detailed information
- Course detail view (description, schedule, instructor, fee)
- Apply or enroll in courses directly from the app
- Students can check their enrollment status and history
- Admin can create, edit, and manage courses
- Course categories and subjects support

### ✅ **Notification System**
- Firebase Realtime Database notifications
- Notify when new courses are added
- Notify when new posts are created
- Real-time notification updates
- Mark notifications as read/unread
- Notification count display

### ✅ **Post & Feed Module**
- Admin can create posts (text, photo support)
- Feed display with posts
- Like and comment system
- Post notifications
- Media support for posts

### ✅ **Chat System**
- One-on-one chat between users
- Group chat functionality
- File and image sharing in chat
- Real-time messaging
- Chat notifications

### ✅ **Profile Module**
- User profiles with photo and bio
- Course enrollment history
- Profile editing capabilities
- Change password functionality

### ✅ **Admin Panel**
- Course management (create, edit, delete)
- Post management
- User management
- Admin-only features

---

## 🔄 **Features Currently Being Implemented**

### 🔧 **Notification System Improvements**
- Push notifications for new courses and posts
- Better notification delivery system
- Notification preferences

---

## 📋 **Remaining Features To Implement**

### 1. **Payment Integration**
- Enable payments for course enrollment (KPay, WavePay, MPU, CBPay, etc.)
- Payment receipts (image or PDF)
- Support for both free and paid courses
- Payment status tracking

### 2. **Quiz / Assignment Module**
- Instructors can create quizzes or tests
- Students can submit assignments
- Auto grading or manual checking options
- Quiz results and analytics

### 3. **Certificate Module**
- Automatically generate certificates upon course completion
- Allow students to view/download certificates
- Include unique verification code for each certificate
- Certificate templates

### 4. **Attendance System**
- Daily attendance check-in for students
- QR code or manual attendance
- Instructors can view attendance reports
- Attendance statistics

### 5. **Review & Rating System**
- Students can rate courses
- Text-based feedback/comments for each course
- Rating analytics and reports
- Course recommendations based on ratings

### 6. **Event Calendar**
- Monthly calendar view for classes, exams, and deadlines
- Notifications for upcoming events or courses
- Calendar integration
- Event reminders

### 7. **Bookmark / Save for Later**
- Allow users to save posts or courses for later viewing
- Bookmark management
- Quick access to saved items

### 8. **Advanced Chat Features**
- Voice messages
- Video calls integration
- Chat search functionality
- Message reactions

### 9. **Advanced Course Features**
- Course progress tracking
- Course materials upload/download
- Course completion certificates
- Course prerequisites

### 10. **Analytics Dashboard**
- User engagement analytics
- Course performance metrics
- Revenue tracking (for paid courses)
- Admin dashboard with charts

---

## 🛠 **Tech Stack**

- **Frontend**: Flutter
- **Backend**: Firebase (Auth, Realtime Database, Storage)
- **Cloud Storage**: Firebase Storage
- **Notifications**: Firebase Realtime Database
- **State Management**: Flutter built-in state management

---

## 📱 **App Structure**

```
lib/
├── main.dart
├── firebase_options.dart
├── screens/
│   ├── auth/
│   │   ├── login_screen.dart
│   │   ├── register_screen.dart
│   │   ├── forgot_password_screen.dart
│   │   └── otp_verification_screen.dart
│   ├── courses/
│   │   ├── course_list_screen.dart
│   │   ├── course_detail_screen.dart
│   │   ├── course_create_screen.dart
│   │   └── enrollment_form_screen.dart
│   ├── feed_screen.dart
│   ├── create_post_screen.dart
│   ├── chat_screen.dart
│   ├── notification_screen.dart
│   ├── profile_screen.dart
│   └── admin_panel_screen.dart
├── services/
│   └── notification_service.dart
└── utils/
```

---

## 🚀 **Getting Started**

1. Clone the repository
2. Install Flutter dependencies: `flutter pub get`
3. Configure Firebase project
4. Update Firebase configuration in `firebase_options.dart`
5. Run the app: `flutter run`

---

## 📝 **Recent Updates**

- ✅ Fixed register button navigation issue
- ✅ Improved notification system for new courses and posts
- ✅ Added debugging for notification delivery
- ✅ Enhanced notification service with better error handling

---

## 🔧 **Known Issues & Fixes**

### Fixed Issues:
- ✅ Register button not working from login screen
- ✅ Notifications not being sent for new courses and posts

### Current Issues:
- 🔄 Notification delivery needs testing
- 🔄 Push notifications not implemented yet

---

## 📞 **Support**

For support and questions, please contact the development team.

---

*Last updated: December 2024*
