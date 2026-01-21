/* global axios */
import ApiClient from './ApiClient';

class UploadAPI extends ApiClient {
  constructor() {
    super('upload', { accountScoped: true });
  }

  uploadAttachment(file) {
    const formData = new FormData();
    formData.append('attachment', file);
    return axios.post(this.url, formData);
  }

  uploadFromUrl(externalUrl) {
    return axios.post(this.url, { external_url: externalUrl });
  }

  deleteAttachment({ blobKey, blobId }) {
    return axios.delete(this.url, {
      data: { blob_key: blobKey, blob_id: blobId }
    });
  }
}

export default new UploadAPI();
