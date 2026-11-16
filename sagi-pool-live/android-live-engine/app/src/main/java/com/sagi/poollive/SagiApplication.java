package com.sagi.poollive;

import android.app.Application;
import android.util.Log;
import com.tencent.live2.V2TXLivePremier;
import com.tencent.live2.V2TXLivePremierObserver;

public class SagiApplication extends Application {
    private static final String TAG = "SagiPoolLive";

    @Override
    public void onCreate() {
        super.onCreate();
        if (!BuildConfig.LIVE_LICENSE_URL.isEmpty() && !BuildConfig.LIVE_LICENSE_KEY.isEmpty()) {
            V2TXLivePremier.setObserver(new V2TXLivePremierObserver() {
                @Override
                public void onLicenceLoaded(int result, String reason) {
                    Log.i(TAG, "LiteAV licence result=" + result + " reason=" + reason);
                }
            });
            V2TXLivePremier.setLicence(this, BuildConfig.LIVE_LICENSE_URL, BuildConfig.LIVE_LICENSE_KEY);
        } else {
            Log.w(TAG, "Tencent Live licence is not configured.");
        }
    }
}
