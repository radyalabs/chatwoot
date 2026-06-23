<template>
  <!-- Menambahkan flex-1 dan w-full agar mengisi seluruh area kosong -->
  <div class="flex-1 w-full h-full overflow-hidden bg-white dark:bg-slate-900">
    <router-view />
  </div>
</template>

<script>
export default {
  name: 'BlastingWrapper',
};
</script>