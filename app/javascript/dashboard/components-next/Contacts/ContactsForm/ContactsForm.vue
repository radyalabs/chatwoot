<script setup>
import { computed, onUnmounted, reactive, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { required, email } from '@vuelidate/validators';
import { useVuelidate } from '@vuelidate/core';
import { splitName } from '@chatwoot/utils';
import countries from 'shared/constants/countries.js';
import Input from 'dashboard/components-next/input/Input.vue';
import ComboBox from 'dashboard/components-next/combobox/ComboBox.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import PhoneNumberInput from 'dashboard/components-next/phonenumberinput/PhoneNumberInput.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import { useStore, useMapGetter } from 'dashboard/composables/store';

const props = defineProps({
  contactData: {
    type: Object,
    default: null,
  },
  isDetailsView: {
    type: Boolean,
    default: false,
  },
  isNewContact: {
    type: Boolean,
    default: false,
  },
});

const emit = defineEmits(['update', 'removeCustomAttr']);

const { t } = useI18n();

const store = useStore();
const contactAttributeKeys = useMapGetter('contactAttributeKeys/getContactAttributeKeys');

const FORM_CONFIG = {
  FIRST_NAME: { field: 'firstName' },
  LAST_NAME: { field: 'lastName' },
  EMAIL_ADDRESS: { field: 'email' },
  PHONE_NUMBER: { field: 'phoneNumber' },
  CITY: { field: 'additionalAttributes.city' },
  COUNTRY: { field: 'additionalAttributes.countryCode' },
  BIO: { field: 'additionalAttributes.description' },
  COMPANY_NAME: { field: 'additionalAttributes.companyName' },
};

const SOCIAL_CONFIG = {
  LINKEDIN: 'i-ri-linkedin-box-fill',
  FACEBOOK: 'i-ri-facebook-circle-fill',
  INSTAGRAM: 'i-ri-instagram-line',
  TWITTER: 'i-ri-twitter-x-fill',
  // GITHUB: 'i-ri-github-fill',
};

const defaultState = {
  id: 0,
  name: '',
  email: '',
  firstName: '',
  lastName: '',
  phoneNumber: '',
  additionalAttributes: {
    description: '',
    companyName: '',
    countryCode: '',
    country: '',
    city: '',
    socialProfiles: {
      facebook: '',
      github: '',
      instagram: '',
      linkedin: '',
      twitter: '',
    },
  },
  customAttributes: {},
};

const state = reactive({ ...defaultState });

const validationRules = {
  firstName: { required },
  email: { email },
};

const v$ = useVuelidate(validationRules, state);

const isFormInvalid = computed(() => v$.value.$invalid);

const prepareStateBasedOnProps = () => {
  if (props.isNewContact) {
    return; // Added to prevent state update for new contact form
  }

  const {
    id,
    name = '',
    email: emailAddress,
    phoneNumber,
    additionalAttributes = {},
    customAttributes = {},
  } = props.contactData || {};
  const { firstName, lastName } = splitName(name || '');
  const {
    description = '',
    companyName = '',
    countryCode = '',
    country = '',
    city = '',
    socialProfiles = {},
  } = additionalAttributes || {};

  // Separate standard keys from custom attributes
  const standardKeys = [
    'description',
    'companyName',
    'countryCode',
    'country',
    'city',
    'socialProfiles',
  ];
  const customAttrs = Object.entries(customAttributes || {}).reduce(
    (acc, [key, value]) => {
      if (!standardKeys.includes(key)) {
        acc[key] = value;
      }
      return acc;
    },
    {}
  );

  Object.assign(state, {
    id,
    name,
    firstName,
    lastName,
    email: emailAddress,
    phoneNumber,
    additionalAttributes: {
      description,
      companyName,
      countryCode,
      country,
      city,
      socialProfiles,
    },
    customAttributes: customAttrs,
  });
};

const countryOptions = computed(() =>
  countries.map(({ name, id }) => ({ label: name, value: id }))
);

const editDetailsForm = computed(() =>
  Object.keys(FORM_CONFIG).map(key => ({
    key,
    placeholder: t(
      `CONTACTS_LAYOUT.CARD.EDIT_DETAILS_FORM.FORM.${key}.PLACEHOLDER`
    ),
  }))
);

const socialProfilesForm = computed(() =>
  Object.entries(SOCIAL_CONFIG).map(([key, icon]) => ({
    key,
    placeholder: t(`CONTACTS_LAYOUT.CARD.SOCIAL_MEDIA.FORM.${key}.PLACEHOLDER`),
    icon,
  }))
);

const isValidationField = key => {
  const field = FORM_CONFIG[key]?.field;
  return ['firstName', 'email'].includes(field);
};

const getValidationKey = key => {
  return FORM_CONFIG[key]?.field;
};

// Creates a computed property for two-way form field binding
const getFormBinding = key => {
  const field = FORM_CONFIG[key]?.field;
  if (!field) return null;

  return computed({
    get: () => {
      // Handle firstName/lastName fields
      if (field === 'firstName' || field === 'lastName') {
        return state[field]?.toString() || '';
      }

      // Handle nested vs non-nested fields
      const [base, nested] = field.split('.');
      // Example: 'email' → state.email
      // Example: 'additionalAttributes.city' → state.additionalAttributes.city
      return (nested ? state[base][nested] : state[base])?.toString() || '';
    },

    set: async value => {
      // Handle name fields specially to maintain the combined 'name' field
      if (field === 'firstName' || field === 'lastName') {
        state[field] = value;
        // Example: firstName="John", lastName="Doe" → name="John Doe"
        state.name = `${state.firstName} ${state.lastName}`.trim();
      } else {
        // Handle nested vs non-nested fields
        const [base, nested] = field.split('.');
        if (nested) {
          // Example: additionalAttributes.city = "New York"
          state[base][nested] = value;
        } else {
          // Example: email = "test@example.com"
          state[base] = value;
        }
      }

      const isFormValid = await v$.value.$validate();
      if (isFormValid) {
        const { firstName, lastName, ...stateWithoutNames } = state;
        emit('update', stateWithoutNames);
      }
    },
  });
};

const getMessageType = key => {
  return isValidationField(key) && v$.value[getValidationKey(key)]?.$error
    ? 'error'
    : 'info';
};

const handleCountrySelection = value => {
  const selectedCountry = countries.find(option => option.id === value);
  state.additionalAttributes.country = selectedCountry?.name || '';
  emit('update', state);
};

const resetValidation = () => {
  v$.value.$reset();
};

const resetForm = () => {
  Object.assign(state, defaultState);
};

const newCustomAttrKey = ref('');
const newCustomAttrValue = ref('');
const newCustomAttrDataType = ref('text');
const showKeyDropdown = ref(false);
const newKeyInput = ref('');

const customAttrsDisplay = computed(() => state.customAttributes || {});

// Attribute keys defined in the system but not yet added to this contact
const availableAttributeKeys = computed(() => {
  const existing = Object.keys(customAttrsDisplay.value);
  return (contactAttributeKeys.value || []).filter(
    r => !existing.includes(r.key)
  );
});

const selectExistingKey = r => {
  newCustomAttrKey.value = r.key;
  newCustomAttrDataType.value = r.data_type || 'text';
  showKeyDropdown.value = false;
};

const selectNewKey = () => {
  if (!newKeyInput.value.trim()) return;
  newCustomAttrKey.value = newKeyInput.value.trim();
  newKeyInput.value = '';
  showKeyDropdown.value = false;
};

const setDataType = dt => {
  newCustomAttrDataType.value = dt;
};

const closeDropdownOnOutsideClick = e => {
  if (!e.target.closest('[data-key-dropdown]')) {
    showKeyDropdown.value = false;
  }
};

document.addEventListener('click', closeDropdownOnOutsideClick);
onUnmounted(() => document.removeEventListener('click', closeDropdownOnOutsideClick));

const addCustomAttr = async () => {
  if (!newCustomAttrKey.value.trim()) return;

  const key = newCustomAttrKey.value.trim();
  const dataType = newCustomAttrDataType.value;
  const value = newCustomAttrValue.value?.trim?.() ?? String(newCustomAttrValue.value ?? '');

  if (!state.customAttributes) state.customAttributes = {};
  state.customAttributes[key] = value;

  newCustomAttrDataType.value = 'text';
  newCustomAttrKey.value = '';
  newCustomAttrValue.value = '';
  showKeyDropdown.value = false;
  emit('update', state);

  const exists = (contactAttributeKeys.value || []).some(r => r.key === key);
  if (!exists) {
    await store.dispatch('contactAttributeKeys/create', { key, dataType });
  }
};

const pendingDeleteKey = ref(null);

const handleTrashClick = key => {
  pendingDeleteKey.value = pendingDeleteKey.value === key ? null : key;
};

const removeFromContact = key => {
  const newAttrs = {};
  Object.keys(state.customAttributes).forEach(k => {
    if (k !== key) newAttrs[k] = state.customAttributes[k];
  });
  state.customAttributes = newAttrs;
  pendingDeleteKey.value = null;
  emit('removeCustomAttr', key);
};

const removeDefinition = async key => {
  const record = (contactAttributeKeys.value || []).find(r => r.key === key);
  if (record) {
    await store.dispatch('contactAttributeKeys/destroy', record.id);
  }
  removeFromContact(key);
};

watch(() => props.contactData, prepareStateBasedOnProps, {
  immediate: true,
  deep: true,
});

const hasPendingAttr = computed(() => !!newCustomAttrKey.value.trim());

const flushPendingAttr = async () => {
  if (hasPendingAttr.value) await addCustomAttr();
};

// Expose state to parent component for avatar upload
defineExpose({
  state,
  resetValidation,
  isFormInvalid,
  resetForm,
  flushPendingAttr,
  hasPendingAttr,
});
</script>

<template>
  <div class="flex flex-col gap-6">
    <div class="flex flex-col items-start gap-2">
      <span class="py-1 text-sm font-medium text-n-slate-12">
        {{ t('CONTACTS_LAYOUT.CARD.EDIT_DETAILS_FORM.TITLE') }}
      </span>
      <div class="grid w-full grid-cols-1 gap-4 sm:grid-cols-2">
        <template v-for="item in editDetailsForm" :key="item.key">
          <ComboBox
            v-if="item.key === 'COUNTRY'"
            v-model="state.additionalAttributes.countryCode"
            :options="countryOptions"
            :placeholder="item.placeholder"
            class="[&>div>button]:h-8"
            :class="{
              '[&>div>button]:bg-n-alpha-black2 [&>div>button]:!outline-transparent':
                !isDetailsView,
              '[&>div>button]:!outline-n-weak [&>div>button]:hover:!outline-n-strong [&>div>button]:!bg-n-alpha-black2':
                isDetailsView,
            }"
            @update:model-value="handleCountrySelection"
          />
          <PhoneNumberInput
            v-else-if="item.key === 'PHONE_NUMBER'"
            v-model="getFormBinding(item.key).value"
            :placeholder="item.placeholder"
            :show-border="isDetailsView"
          />
          <Input
            v-else
            v-model="getFormBinding(item.key).value"
            :placeholder="item.placeholder"
            :message-type="getMessageType(item.key)"
            :custom-input-class="`h-8 !pt-1 !pb-1 ${
              !isDetailsView ? '[&:not(.error,.focus)]:!border-transparent' : ''
            }`"
            class="w-full"
            @input="
              isValidationField(item.key) &&
                v$[getValidationKey(item.key)].$touch()
            "
            @blur="
              isValidationField(item.key) &&
                v$[getValidationKey(item.key)].$touch()
            "
          />
        </template>
      </div>
    </div>
    <div class="flex flex-col items-start gap-2">
      <span class="py-1 text-sm font-medium text-n-slate-12">
        {{ t('CONTACTS_LAYOUT.CARD.SOCIAL_MEDIA.TITLE') }}
      </span>
      <div class="flex flex-wrap gap-2">
        <div
          v-for="item in socialProfilesForm"
          :key="item.key"
          class="flex items-center h-8 gap-2 px-2 rounded-lg"
          :class="{
            'bg-n-alpha-2 dark:bg-n-solid-2': isDetailsView,
            'bg-n-alpha-2 dark:bg-n-solid-3': !isDetailsView,
          }"
        >
          <Icon
            :icon="item.icon"
            class="flex-shrink-0 text-n-slate-11 size-4"
          />
          <input
            v-model="
              state.additionalAttributes.socialProfiles[item.key.toLowerCase()]
            "
            class="w-auto min-w-[100px] text-sm bg-transparent reset-base text-n-slate-12 dark:text-n-slate-12 placeholder:text-n-slate-10 dark:placeholder:text-n-slate-10"
            :placeholder="item.placeholder"
            :size="item.placeholder.length"
            @input="emit('update', state)"
          />
        </div>
      </div>
    </div>
    <div
      v-if="Object.keys(customAttrsDisplay).length > 0"
      class="flex flex-col w-full gap-3 p-4 rounded-lg bg-n-alpha-black2"
    >
      <span class="text-base font-semibold text-n-slate-12">
        {{ t('CONTACTS_LAYOUT.CARD.CUSTOM_ATTRIBUTES.TITLE') }}
      </span>
      <div class="grid w-full grid-cols-1 gap-4 sm:grid-cols-2">
        <template v-for="(value, key) in customAttrsDisplay" :key="key">
          <div class="flex flex-col items-start gap-2">
            <span class="text-sm font-medium text-n-slate-12">{{ key }}</span>
            <div class="flex items-center w-full gap-2">
              <Input
                v-model="state.customAttributes[key]"
                :placeholder="'Masukkan ' + key + ' Anda'"
                class="flex-1"
                @input="emit('update', state)"
              />
              <button
                type="button"
                class="flex items-center justify-center p-2 text-n-slate-10 rounded-md hover:bg-n-ruby-4 hover:text-n-ruby-11"
                @click="handleTrashClick(key)"
              >
                <Icon icon="i-lucide-trash-2" class="size-4" />
              </button>
            </div>
            <div
              v-if="pendingDeleteKey === key"
              class="flex items-center gap-2"
            >
              <span class="text-xs text-n-slate-11">Hapus:</span>
              <button
                type="button"
                class="px-2 py-0.5 text-xs rounded bg-n-alpha-black2 text-n-slate-12 hover:bg-n-ruby-4 hover:text-n-ruby-11"
                @click="removeFromContact(key)"
              >
                {{ t('CONTACTS_LAYOUT.CARD.CUSTOM_ATTRIBUTES.DELETE_CONTACT') }}
              </button>
              <button
                type="button"
                class="px-2 py-0.5 text-xs rounded bg-n-alpha-black2 text-n-slate-12 hover:bg-n-ruby-4 hover:text-n-ruby-11"
                @click="removeDefinition(key)"
              >
                {{ t('CONTACTS_LAYOUT.CARD.CUSTOM_ATTRIBUTES.DELETE_ALL') }}
              </button>
              <button
                type="button"
                class="text-n-slate-10 hover:text-n-slate-12"
                @click="pendingDeleteKey = null"
              >
                <Icon icon="i-lucide-x" class="size-3" />
              </button>
            </div>
          </div>
        </template>
      </div>
    </div>
    <div class="flex flex-col items-start gap-3">
      <span
        v-if="Object.keys(customAttrsDisplay).length === 0"
        class="py-1 text-sm font-medium text-n-slate-12"
      >
        {{ t('CONTACTS_LAYOUT.CARD.CUSTOM_ATTRIBUTES.TITLE') }}
      </span>
      <div class="flex flex-col gap-1.5 w-full">
      <div
        class="flex items-end gap-2 w-full rounded-xl transition-all duration-300"
        :class="hasPendingAttr ? 'bg-n-amber-3 dark:bg-n-amber-2 ring-1 ring-n-amber-8 p-2.5' : ''"
      >
        <!-- Key dropdown -->
        <div class="flex flex-col gap-1 flex-1" data-key-dropdown>
          <span class="text-xs text-n-slate-11">
            {{ t('CONTACTS_LAYOUT.CARD.CUSTOM_ATTRIBUTES.KEY_PLACEHOLDER') }}
          </span>
          <div class="relative">
            <button
              type="button"
              class="h-8 w-full px-2 text-sm border border-n-weak rounded-lg bg-n-alpha-black2 text-left flex items-center justify-between gap-1 focus:outline-none focus:border-n-brand"
              :class="newCustomAttrKey ? 'text-n-slate-12' : 'text-n-slate-10'"
              @click.stop="showKeyDropdown = !showKeyDropdown"
            >
              <span class="truncate">{{ newCustomAttrKey || t('CONTACTS_LAYOUT.CARD.CUSTOM_ATTRIBUTES.KEY_PLACEHOLDER') }}</span>
              <Icon icon="i-lucide-chevron-down" class="size-3 flex-shrink-0 text-n-slate-10" />
            </button>
            <div
              v-if="showKeyDropdown"
              class="absolute top-full left-0 mt-1 w-full min-w-[160px] bg-n-solid-1 border border-n-weak rounded-lg shadow-lg z-50 overflow-hidden"
            >
              <div class="max-h-40 overflow-y-auto">
                <button
                  v-for="r in availableAttributeKeys"
                  :key="r.key"
                  type="button"
                  class="w-full px-3 py-1.5 text-sm text-left text-n-slate-12 hover:bg-n-alpha-2 flex items-center justify-between gap-2"
                  @click.stop="selectExistingKey(r)"
                >
                  <span class="truncate">{{ r.key }}</span>
                  <span class="text-xs text-n-slate-10 flex-shrink-0">{{ r.data_type }}</span>
                </button>
                <p
                  v-if="!availableAttributeKeys.length"
                  class="px-3 py-2 text-xs text-n-slate-10"
                >
                  {{ t('CONTACTS_LAYOUT.CARD.CUSTOM_ATTRIBUTES.NO_AVAILABLE_KEYS') }}
                </p>
              </div>
              <div class="border-t border-n-weak p-2 flex flex-col gap-1.5">
                <input
                  v-model="newKeyInput"
                  type="text"
                  :placeholder="t('CONTACTS_LAYOUT.CARD.CUSTOM_ATTRIBUTES.NEW_KEY_PLACEHOLDER')"
                  class="h-7 w-full px-2 text-sm border border-n-weak rounded-md bg-n-alpha-black2 text-n-slate-12 placeholder:text-n-slate-10 focus:outline-none focus:border-n-brand"
                  @click.stop
                  @keyup.enter="selectNewKey"
                />
                <div class="flex gap-1" @click.stop>
                  <button
                    v-for="dt in ['text', 'number', 'date']"
                    :key="dt"
                    type="button"
                    class="flex-1 py-0.5 text-xs rounded border transition-colors"
                    :class="newCustomAttrDataType === dt
                      ? 'bg-n-brand text-white border-n-brand'
                      : 'border-n-weak text-n-slate-11 hover:bg-n-alpha-2'"
                    @click="setDataType(dt)"
                  >
                    {{ dt }}
                  </button>
                </div>
              </div>
            </div>
          </div>
        </div>
        <!-- Value input -->
        <div class="flex flex-col gap-1 flex-1">
          <span class="text-xs text-n-slate-11">
            {{ t('CONTACTS_LAYOUT.CARD.CUSTOM_ATTRIBUTES.VALUE_PLACEHOLDER') }}
          </span>
          <input
            v-if="newCustomAttrDataType === 'date'"
            v-model="newCustomAttrValue"
            type="date"
            class="h-8 w-full px-2 text-sm border border-n-weak rounded-lg bg-n-alpha-black2 text-n-slate-12 focus:outline-none focus:border-n-brand"
          />
          <Input
            v-else
            v-model="newCustomAttrValue"
            :type="newCustomAttrDataType === 'number' ? 'number' : 'text'"
            :placeholder="newCustomAttrKey ? t('CONTACTS_LAYOUT.CARD.CUSTOM_ATTRIBUTES.VALUE_WITH_KEY', { key: newCustomAttrKey }) : t('CONTACTS_LAYOUT.CARD.CUSTOM_ATTRIBUTES.VALUE_PLACEHOLDER')"
            :custom-input-class="'h-8 !pt-1 !pb-1'"
          />
        </div>
        <!-- Add button -->
        <Button
          size="sm"
          class="mb-0.5 transition-all duration-200"
          :amber="hasPendingAttr"
          @click="addCustomAttr"
        >
          <Icon icon="i-lucide-plus" class="size-4" />
        </Button>
      </div>
      <Transition
        enter-active-class="transition-all duration-200 ease-out"
        enter-from-class="opacity-0 -translate-y-1"
        enter-to-class="opacity-100 translate-y-0"
        leave-active-class="transition-all duration-150 ease-in"
        leave-from-class="opacity-100 translate-y-0"
        leave-to-class="opacity-0 -translate-y-1"
      >
        <p
          v-if="hasPendingAttr"
          class="flex items-center gap-1.5 text-xs text-n-amber-11 px-1"
        >
          <Icon icon="i-lucide-circle-alert" class="size-3 flex-shrink-0" />
          Klik <span class="font-semibold">+</span> untuk menambah, atau langsung klik Perbarui kontak
        </p>
      </Transition>
      </div>
    </div>
  </div>
</template>
