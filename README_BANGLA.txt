RTN Chat Real Supabase Final
=============================

Ei version localStorage demo na. Ei version Supabase database/storage/realtime use kore.
Tai ek user post/like/message korle onno user refresh/realtime e dekhte pabe.

FILES:
- user-app.html = user website
- admin-panel.html = admin panel, chat dekhar option nai
- SUPABASE_REAL_SETUP.sql = database/table/storage/realtime setup
- START_RTN_CHAT.bat = localhost diye user website open korar easy button
- OPEN_ADMIN_PANEL.bat = admin panel open korar button
- local-server.js = no-dependency local HTTP server

FIRST SETUP:
1) Supabase Dashboard open koro
2) SQL Editor -> New Query
3) SUPABASE_REAL_SETUP.sql file open kore sob copy paste koro
4) Run koro

IMPORTANT:
File double click kore file:// diye open korba na.
Camera, video call, storage upload, realtime properly kaj korte localhost/http lagbe.

RUN:
1) START_RTN_CHAT.bat double click koro
2) Browser e open hobe: http://localhost:8080/user-app.html
3) Admin panel: http://localhost:8080/admin-panel.html

USER ACCOUNT:
- Create account korte password minimum 6 character dite hobe. Eta Supabase Auth rule.
- Example: password 123456 ba 20262026

ADMIN:
- Admin panel e prothome normal Supabase account login/sign up korte hobe.
- Tarpor Admin Code dite hobe: 2026
- First admin only code diye claim korte parbe.
- Admin account password 4 digit hote pare na jodi Supabase min 6 thake, tai account password 123456/20262026 dao, admin code 2026 dao.

FEATURES:
- Real account create/login
- Real profile/avatar/cover/bio/note
- Clear friend request send/accept/reject page
- Accept korle notification jay
- Notifications page clear
- Realtime posts/likes/comments
- Story create/view
- Messenger chat list
- Friend hole photo/file/audio/video call allowed
- Non-friend hole text message only
- Message Sent/Delivered/Read status
- Blue badge apply -> admin approve/reject
- Admin user ban/unban, blue badge, post/story/report/settings control
- Admin panel e private chat view nei
- Real WebRTC audio/video call basic added with Supabase realtime signaling

CALL NOTE:
Audio/video call HTTPS/localhost e best kaj kore. Basic STUN deoa ache.
Different network/mobile data e stable call er jonno paid/free TURN server lagte pare.

IF ANYTHING NOT WORKS:
- Supabase SQL setup run hoyeche kina check koro
- Website localhost diye open koro
- Browser camera/microphone permission allow koro
- Supabase Auth email confirmation jodi ON thake, email confirm korte hobe or dashboard theke disable korte hobe
