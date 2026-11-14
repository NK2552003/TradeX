package com.example.tradex

import android.content.Context
import android.os.Build
import android.view.WindowInsets
import android.view.WindowInsetsAnimation
import android.widget.FrameLayout
import io.flutter.embedding.android.FlutterFragmentActivity

class MainActivity : FlutterFragmentActivity() {
    override fun provideRootLayout(context: Context): FrameLayout {
        val root = super.provideRootLayout(context)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            // Flutter defers IME insets during the animation. A back swipe can
            // finish (or be cancelled) with different insets than it started with.
            // Ask for the settled values after Flutter's own onEnd has run.
            root.setWindowInsetsAnimationCallback(object : WindowInsetsAnimation.Callback(
                WindowInsetsAnimation.Callback.DISPATCH_MODE_CONTINUE_ON_SUBTREE
            ) {
                override fun onProgress(
                    insets: WindowInsets,
                    runningAnimations: MutableList<WindowInsetsAnimation>
                ): WindowInsets = insets

                override fun onEnd(animation: WindowInsetsAnimation) {
                    if ((animation.typeMask and WindowInsets.Type.ime()) != 0) {
                        root.post { root.requestApplyInsets() }
                    }
                }
            })
        }
        return root
    }
}
