<script setup>
import { ref, computed } from 'vue';
import { useMapGetter } from 'dashboard/composables/store';
import { useI18n } from 'vue-i18n';

import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import ContactsForm from 'dashboard/components-next/Contacts/ContactsForm/ContactsForm.vue';

const emit = defineEmits(['create']);

const { t } = useI18n();

const dialogRef = ref(null);
const contactsFormRef = ref(null);
const contact = ref(null);
const errorMessage = ref('');

const uiFlags = useMapGetter('contacts/getUIFlags');
const isCreatingContact = computed(() => uiFlags.value.isCreating);

const createNewContact = contactItem => {
  contact.value = contactItem;
};

const handleDialogConfirm = async () => {
  if (!contact.value) return;
  await contactsFormRef.value?.flushPendingAttr?.();
  emit('create', contact.value);
};

const onSuccess = () => {
  errorMessage.value = '';
  contactsFormRef.value?.resetForm();
  dialogRef.value.close();
};

const showError = message => {
  errorMessage.value = message;
};

const closeDialog = () => {
  errorMessage.value = '';
  dialogRef.value.close();
};

defineExpose({ dialogRef, contactsFormRef, onSuccess, showError });
</script>

<template>
  <Dialog ref="dialogRef" width="3xl" @confirm="handleDialogConfirm">
    <ContactsForm
      ref="contactsFormRef"
      is-new-contact
      @update="createNewContact"
    />
    <template #footer>
      <div class="flex flex-col w-full gap-2">
        <p v-if="errorMessage" class="text-sm text-n-ruby-11 text-right">
          {{ errorMessage }}
        </p>
        <div class="flex items-center justify-between w-full gap-3">
          <Button
            :label="t('DIALOG.BUTTONS.CANCEL')"
            variant="link"
            class="h-10 hover:!no-underline hover:text-n-brand"
            @click="closeDialog"
          />
          <Button
            :label="
              t('CONTACTS_LAYOUT.HEADER.ACTIONS.CONTACT_CREATION.SAVE_CONTACT')
            "
            color="blue"
            :disabled="contactsFormRef?.isFormInvalid"
            :is-loading="isCreatingContact"
            @click="handleDialogConfirm"
          />
        </div>
      </div>
    </template>
  </Dialog>
</template>
