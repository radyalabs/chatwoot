<template>
  <div class="w-full">
    <!-- Baris Tombol Variabel (Disesuaikan agar terlihat seperti tag Chatwoot) -->
    <div class="flex items-center gap-2 mb-3">
      <span class="text-xs font-semibold text-slate-500 dark:text-slate-400">Sisipkan:</span>
      <button 
        v-for="variabel in availableVariables" 
        :key="variabel.key"
        type="button" 
        class="button tiny hollow"
        @click="insertVariable(variabel.key)"
      >
        {{ variabel.label }}
      </button>
    </div>

    <!-- Text Area -->
    <textarea 
      ref="textAreaRef"
      :value="modelValue"
      @input="onInput"
      class="w-full p-3 text-sm bg-white border rounded-md dark:bg-slate-900 border-slate-300 dark:border-slate-700 text-slate-900 dark:text-slate-100 focus:border-woot-500 focus:ring-1 focus:ring-woot-500 outline-none min-h-[200px] resize-y" 
      placeholder="Halo {{full_name}}, ada penawaran spesial untuk Anda hari ini..."
    ></textarea>
  </div>
</template>

<script>
export default {
  name: 'MessageEditor',
  props: {
    modelValue: {
      type: String,
      default: '',
    },
  },
  emits: ['update:modelValue'],
  data() {
    return {
      availableVariables: [
        { label: 'Nama Lengkap', key: '{{full_name}}' },
        { label: 'Nama Depan', key: '{{first_name}}' },
        { label: 'Nomor HP', key: '{{phone_number}}' },
      ],
    };
  },
  methods: {
    onInput(event) {
      this.$emit('update:modelValue', event.target.value);
    },
    insertVariable(variableKey) {
      const textarea = this.$refs.textAreaRef;
      const start = textarea.selectionStart;
      const end = textarea.selectionEnd;
      
      const textBefore = this.modelValue.substring(0, start);
      const textAfter = this.modelValue.substring(end);
      
      const newValue = textBefore + variableKey + textAfter;
      
      this.$emit('update:modelValue', newValue);
      
      this.$nextTick(() => {
        textarea.focus();
        textarea.selectionEnd = start + variableKey.length;
      });
    },
  },
};
</script>