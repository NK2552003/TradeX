package com.nk2552003.alphajournal

import android.content.Context
import android.os.Build
import android.view.WindowInsets
import android.view.WindowInsetsAnimation
import android.widget.FrameLayout
import io.flutter.embedding.android.FlutterFragment
import io.flutter.embedding.android.FlutterView
import io.flutter.embedding.android.FlutterFragmentActivity

class MainActivity : FlutterFragmentActivity() {
    override fun provideRootLayout(context: Context): FrameLayout {
        val root = super.provideRootLayout(context)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            var imeAnimating = false
            var imeWasVisible = false
            fun syncSettledInsets() {
                root.postOnAnimation {
                    if (!imeAnimating && root.isAttachedToWindow) {
                        val insets = root.rootWindowInsets ?: return@postOnAnimation
                        val flutterView = root.findViewById<FlutterView>(FlutterFragment.FLUTTER_VIEW_ID)
                        // Deliver the current values directly after Flutter's deferred
                        // animation callback, which can retain a cancelled swipe's values.
                        flutterView?.onApplyWindowInsets(insets)
                        flutterView?.requestLayout()
                        root.requestLayout()
                        root.requestApplyInsets()
                    }
                }
            }
            root.viewTreeObserver.addOnGlobalLayoutListener {
                val visible = root.rootWindowInsets?.isVisible(WindowInsets.Type.ime()) ?: false
                if (imeWasVisible && !visible && !imeAnimating) syncSettledInsets()
                imeWasVisible = visible
            }
            // Flutter defers IME insets during the animation. A back swipe can
            // finish (or be cancelled) with different insets than it started with.
            // Ask for the settled values after Flutter's own onEnd has run.
            root.setWindowInsetsAnimationCallback(object : WindowInsetsAnimation.Callback(
                WindowInsetsAnimation.Callback.DISPATCH_MODE_CONTINUE_ON_SUBTREE
            ) {
                override fun onPrepare(animation: WindowInsetsAnimation) {
                    if ((animation.typeMask and WindowInsets.Type.ime()) != 0) imeAnimating = true
                }

                override fun onProgress(
                    insets: WindowInsets,
                    runningAnimations: MutableList<WindowInsetsAnimation>
                ): WindowInsets = insets

                override fun onEnd(animation: WindowInsetsAnimation) {
                    if ((animation.typeMask and WindowInsets.Type.ime()) != 0) {
                        imeAnimating = false
                        syncSettledInsets()
                    }
                }
            })
        }
        return root
    }
}
