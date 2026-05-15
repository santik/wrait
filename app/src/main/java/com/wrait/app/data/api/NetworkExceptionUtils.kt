package com.wrait.app.data.api

import java.io.InterruptedIOException
import java.net.SocketTimeoutException

/**
 * OkHttp may surface timeouts either as [SocketTimeoutException] or as a more generic
 * [InterruptedIOException], so both map to the app's timeout classification.
 */
internal fun Throwable.isNetworkTimeout(): Boolean {
    return this is SocketTimeoutException || this is InterruptedIOException
}
