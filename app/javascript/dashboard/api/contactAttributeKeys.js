/* global axios */
import ApiClient from './ApiClient';

class ContactAttributeKeysAPI extends ApiClient {
  constructor() {
    super('contact_attribute_keys', { accountScoped: true });
  }

  get() {
    return axios.get(this.url);
  }

  create(key) {
    return axios.post(this.url, { key });
  }

  delete(id) {
    return axios.delete(`${this.url}/${id}`);
  }
}

export default new ContactAttributeKeysAPI();
