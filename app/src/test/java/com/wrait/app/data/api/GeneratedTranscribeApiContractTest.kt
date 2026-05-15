package com.wrait.app.data.api

import com.wrait.app.data.api.generated.api.DefaultApi
import okhttp3.MultipartBody
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import retrofit2.http.Body
import retrofit2.http.Multipart
import retrofit2.http.Part

class GeneratedTranscribeApiContractTest {

    @Test
    fun transcribeAudio_usesMultipartPartInsteadOfBodyByteArray() {
        val method = DefaultApi::class.java.methods.single { candidate ->
            candidate.name == "transcribeAudio"
        }

        assertTrue(method.isAnnotationPresent(Multipart::class.java))
        assertTrue(method.parameterTypes.contains(String::class.java))
        assertTrue(method.parameterTypes.contains(MultipartBody.Part::class.java))
        assertFalse(
            DefaultApi::class.java.methods.any { candidate ->
                candidate.name == "transcribeAudio" &&
                    candidate.parameterTypes.drop(1).any { it == ByteArray::class.java }
            },
        )

        val partParameterAnnotations = method.parameterAnnotations.first { annotations ->
            annotations.any { it.annotationClass.java == Part::class.java }
        }.map { it.annotationClass.java }
        assertTrue(partParameterAnnotations.contains(Part::class.java))
        assertFalse(partParameterAnnotations.contains(Body::class.java))
    }
}
