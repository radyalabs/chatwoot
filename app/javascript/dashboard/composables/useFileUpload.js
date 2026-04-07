import { computed } from 'vue';
import { useMapGetter } from 'dashboard/composables/store';
import { useAlert } from 'dashboard/composables';
import { useI18n } from 'vue-i18n';
import { DirectUpload } from 'activestorage';
import {
  MAXIMUM_FILE_UPLOAD_SIZE,
  MAXIMUM_FILE_UPLOAD_SIZE_TWILIO_SMS_CHANNEL,
} from 'shared/constants/messages';
import { checkFileSizeLimit } from 'shared/helpers/FileHelper';

/**
 * Composable for handling file uploads in conversations
 * @param {Object} options - Configuration options
 * @param {boolean} options.isATwilioSMSChannel - Whether the current channel is Twilio SMS
 * @param {Function} options.attachFile - Callback function to handle file attachment
 * @param {Function} options.updateAttachment - Callback to update attachment when upload completes (tempId, blob) => void
 * @param {Function} options.removeAttachment - Callback to remove attachment on error (tempId) => void
 * @returns {Object} File upload methods and utilities
 */
export const useFileUpload = ({
  isATwilioSMSChannel,
  attachFile,
  updateAttachment,
  removeAttachment,
}) => {
  const { t } = useI18n();

  const accountId = useMapGetter('getCurrentAccountId');
  const currentUser = useMapGetter('getCurrentUser');
  const currentChat = useMapGetter('getSelectedChat');
  const globalConfig = useMapGetter('globalConfig/get');

  const maxFileSize = computed(() =>
    isATwilioSMSChannel
      ? MAXIMUM_FILE_UPLOAD_SIZE_TWILIO_SMS_CHANNEL
      : MAXIMUM_FILE_UPLOAD_SIZE
  );

  const handleDirectFileUpload = file => {
    if (!file) return;

    if (checkFileSizeLimit(file, maxFileSize.value)) {
      // Generate a temporary ID to track this upload
      const tempId = `upload-${Date.now()}-${Math.random().toString(36).substring(2, 11)}`;

      // Immediately attach the file with uploading state so the UI shows it
      attachFile({ file, uploading: true, tempId });

      const upload = new DirectUpload(
        file.file,
        `/api/v1/accounts/${accountId.value}/conversations/${currentChat.value.id}/direct_uploads`,
        {
          directUploadWillCreateBlobWithXHR: xhr => {
            xhr.setRequestHeader(
              'api_access_token',
              currentUser.value.access_token
            );
          },
        }
      );

      upload.create((error, blob) => {
        if (error) {
          useAlert(error);
          // Remove the failed upload from the list
          if (removeAttachment) {
            removeAttachment(tempId);
          }
        } else {
          // Update the attachment with the blob data
          if (updateAttachment) {
            updateAttachment(tempId, blob);
          }
        }
      });
    } else {
      useAlert(
        t('CONVERSATION.FILE_SIZE_LIMIT', {
          MAXIMUM_SUPPORTED_FILE_UPLOAD_SIZE: maxFileSize.value,
        })
      );
    }
  };

  const handleIndirectFileUpload = file => {
    if (!file) return;

    if (checkFileSizeLimit(file, maxFileSize.value)) {
      attachFile({ file });
    } else {
      useAlert(
        t('CONVERSATION.FILE_SIZE_LIMIT', {
          MAXIMUM_SUPPORTED_FILE_UPLOAD_SIZE: maxFileSize.value,
        })
      );
    }
  };

  const onFileUpload = file => {
    if (globalConfig.value.directUploadsEnabled && currentChat.value?.id) {
      handleDirectFileUpload(file);
    } else {
      handleIndirectFileUpload(file);
    }
  };

  return {
    onFileUpload,
  };
};
