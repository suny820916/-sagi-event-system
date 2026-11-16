package com.sagi.poollive;

import android.app.Application;
import android.util.Log;

import com.tencent.live2.V2TXLivePremier;

public class SagiApplication extends Application {
    private static final String TAG = "SagiPoolLive";

    @Override
    public void onCreate() {
        super.onCreate();
        if (!BuildConfig.LIVE_LICENSE_URL.isEmpty() && !BuildConfig.LIVE_LICENSE_KEY.isEmpty()) {
            V2TXLivePremier.setLicence(this, BuildConfig.LIVE_LICENSE_URL, BuildConfig.LIVE_LICENSE_KEY);
            Log.i(TAG, "LiteAV licence configured. SDK=" + V2TXLivePremier.getSDKVersionStr());
        } else {
            Log.w(TAG, "Tencent Live licence is not configured.");
        }
    }
}
