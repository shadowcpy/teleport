package gd.nexus.teleport

import android.app.Activity
import android.content.Intent
import android.os.Bundle

class ShareActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        forwardToMain(intent)
        finish()
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        forwardToMain(intent)
        finish()
    }

    private fun forwardToMain(source: Intent) {
        val target = Intent(this, MainActivity::class.java).apply {
            action = source.action
            type = source.type
            data = source.data
            clipData = source.clipData
            addFlags(
                Intent.FLAG_ACTIVITY_CLEAR_TOP or
                    Intent.FLAG_ACTIVITY_SINGLE_TOP or
                    Intent.FLAG_ACTIVITY_REORDER_TO_FRONT
            )

            val grantFlags =
                source.flags and
                    (Intent.FLAG_GRANT_READ_URI_PERMISSION or
                        Intent.FLAG_GRANT_WRITE_URI_PERMISSION or
                        Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION or
                        Intent.FLAG_GRANT_PREFIX_URI_PERMISSION)
            addFlags(grantFlags)

            source.extras?.let { putExtras(it) }
        }
        startActivity(target)
    }
}
