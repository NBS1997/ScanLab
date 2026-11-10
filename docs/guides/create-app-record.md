# Create the ScanLab App Record in App Store Connect

The bundle ID `com.nbs1997.scanlab` is already registered, so it will appear in the list
below. This takes about five minutes and only has to be done once.

1. Go to **appstoreconnect.apple.com** and sign in.
2. Open **Apps**.
3. Click the blue **+** next to the "Apps" heading and choose **New App**.
4. Fill in the form:
   - **Platforms:** tick **iOS** only.
   - **Name:** `ScanLab`. If it says the name is already in use, try `ScanLab LiDAR`.
     This is the store name only; the phone still shows "ScanLab".
   - **Primary Language:** English (Australia).
   - **Bundle ID:** choose **com.nbs1997.scanlab** from the list.
   - **SKU:** `scanlab-001` (any unique text; only you see it).
   - **User Access:** **Full Access**.
5. Click **Create**.
6. Open the new app, go to the **TestFlight** tab, and check that you are listed under
   **Internal Testing**. If there is no internal group, click **+** next to Internal
   Testing, name it `Owner`, and add yourself.

When you are done, tell me the name you used and the internal group's name.

If anything on the form looks different from this, tell me what you see.
