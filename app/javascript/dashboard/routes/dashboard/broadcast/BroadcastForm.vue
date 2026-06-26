<template>
  <div class="w-full h-full p-6 overflow-y-auto bg-slate-50 dark:bg-slate-900 custom-scrollbar">
    <div class="max-w-[1400px] mx-auto pb-20">

      <div class="mb-8 text-center max-w-2xl mx-auto">
        <h2 class="text-2xl font-bold text-slate-800 dark:text-slate-100 mb-2">
          {{ $t('BROADCAST.ADD_TITLE') }}
        </h2>
        <p class="text-sm text-slate-500 dark:text-slate-400 mb-6">
          {{ $t('BROADCAST.SUBTITLE') }}
        </p>

        <div class="flex items-center justify-center gap-4">
          <div class="flex items-center gap-2" :class="currentStep === 1 ? 'text-green-600' : 'text-slate-400 cursor-pointer hover:text-slate-600'" @click="currentStep = 1">
            <div class="w-8 h-8 rounded-full flex items-center justify-center font-bold text-sm transition-colors" :class="currentStep === 1 ? 'bg-green-100 text-green-700' : 'bg-slate-200 text-slate-500 dark:bg-slate-700 dark:text-slate-400'">1</div>
            <span class="font-semibold text-sm">{{ $t('BROADCAST.STEP_1') }}</span>
          </div>
          <div class="w-12 h-px bg-slate-300 dark:bg-slate-700"></div>
          <div class="flex items-center gap-2" :class="currentStep === 2 ? 'text-green-600' : 'text-slate-400'">
            <div class="w-8 h-8 rounded-full flex items-center justify-center font-bold text-sm transition-colors" :class="currentStep === 2 ? 'bg-green-100 text-green-700' : 'bg-slate-200 text-slate-500 dark:bg-slate-700 dark:text-slate-400'">2</div>
            <span class="font-semibold text-sm">{{ $t('BROADCAST.STEP_2') }}</span>
          </div>
        </div>
      </div>

      <div v-if="currentStep === 1" class="flex flex-col gap-6">
        
        <div class="bg-white dark:bg-slate-800 rounded-xl shadow-sm border border-slate-200 dark:border-slate-700 p-8 flex flex-col md:flex-row gap-8">
          <div class="w-full md:w-1/2">
            <label class="block text-sm font-semibold text-slate-700 dark:text-slate-300 mb-2">
              {{ $t('BROADCAST.INBOX_LABEL') }}
            </label>
            <multiselect
              v-model="selectedInbox"
              :options="whatsappInboxes"
              track-by="id"
              label="name"
              :placeholder="$t('BROADCAST.INBOX_PLACEHOLDER')"
              :searchable="true"
              :allow-empty="false"
              select-label=""
              deselect-label=""
              class="w-full uniform-dropdown"
            >
              <template #noResult>{{ $t('BROADCAST.INBOX_NO_RESULT') }}</template>
            </multiselect>
          </div>

          <div class="w-full md:w-1/2">
            <label class="block text-sm font-semibold text-slate-700 dark:text-slate-300 mb-2">{{ $t('BROADCAST.LABEL_TARGET') }}</label>

            <div v-if="targetMode === 'dropdown'">
              <multiselect
                v-model="selectedSegment"
                :options="segmentOptions"
                track-by="id"
                label="name"
                :placeholder="$t('BROADCAST.SEGMENT_PLACEHOLDER')"
                :searchable="true"
                :allow-empty="false"
                select-label=""
                deselect-label=""
                class="w-full uniform-dropdown"
                @select="onSegmentSelect"
              >
                <template #noResult>{{ $t('BROADCAST.SEGMENT_NO_RESULT') }}</template>
              </multiselect>
              <p class="text-[13px] text-slate-500 mt-2.5">
                {{ $t('BROADCAST.SEGMENT_NOT_FOUND') }}
                <button type="button" @click="targetMode = 'custom'" class="text-green-600 hover:text-green-700 dark:text-green-400 dark:hover:text-green-300 font-medium focus:outline-none transition-colors">
                  {{ $t('BROADCAST.CREATE_SEGMENT') }}
                </button>
              </p>
            </div>

            <div v-else class="p-5 bg-slate-50 dark:bg-slate-900/50 border border-slate-200 dark:border-slate-700 rounded-xl relative">
              <div class="flex justify-between items-center mb-4">
                <h3 class="text-sm font-semibold text-slate-700 dark:text-slate-300 flex items-center gap-2">
                  <span class="i-lucide-filter w-4 h-4 text-green-600" />
                  {{ $t('BROADCAST.CREATE_CUSTOM_FILTER') }}
                </h3>
                <button type="button" @click="cancelCustomMode" class="text-xs font-medium text-slate-500 hover:text-slate-800 dark:text-slate-400 dark:hover:text-slate-200 flex items-center gap-1 bg-white dark:bg-slate-800 border border-slate-200 dark:border-slate-700 px-2 py-1 rounded shadow-sm transition-colors focus:outline-none">
                  <span class="i-lucide-x w-3 h-3"></span> {{ $t('BROADCAST.BTN_CANCEL') }}
                </button>
              </div>

              <ContactFilterBroadcast :estimated-count="estimatedContactCount" :is-fetching-count="isFetchingContactCount" @update:queryPayload="onFilterChange" />

              <div class="mt-4 pt-4 border-t border-slate-200 dark:border-slate-700/50 flex justify-end">
                <button
                  type="button"
                  @click="openSegmentModal"
                  :disabled="!activeFilterPayload || activeFilterPayload.length === 0"
                  class="text-xs font-semibold text-blue-600 bg-blue-50 hover:bg-blue-100 dark:text-blue-400 dark:bg-blue-900/30 dark:hover:bg-blue-900/50 px-4 py-2 rounded-md transition-colors flex items-center gap-1.5 focus:outline-none disabled:opacity-50"
                >
                  <span class="i-lucide-save w-4 h-4"></span>
                  {{ $t('BROADCAST.SAVE_SEGMENT') }}
                </button>
              </div>
            </div>
          </div>
        </div>

        <div class="bg-white dark:bg-slate-800 rounded-xl shadow-sm border border-slate-200 dark:border-slate-700 overflow-hidden flex flex-col h-[400px]">
          <div class="p-4 border-b border-slate-200 dark:border-slate-700 flex justify-between items-center bg-slate-50 dark:bg-slate-900/50">
            <h3 class="font-semibold text-slate-800 dark:text-slate-100 flex items-center gap-2">
              <span class="i-lucide-users w-5 h-5 text-green-600"></span> {{ $t('BROADCAST.RECIPIENT_PREVIEW') }}
            </h3>
            <span class="px-3 py-1 bg-green-100 text-green-700 dark:bg-green-900/30 dark:text-green-400 rounded-full text-xs font-bold">
              {{ $t('BROADCAST.TOTAL_CONTACTS') }} {{ totalItems }} {{ $t('CONVERSATION.SIDEBAR.CONTACT') }}
            </span>
          </div>
          <div class="flex-1 overflow-hidden relative flex flex-col preview-table-container">
            <div v-if="isFetchingContactCount || contactsUiFlags.isFetching" class="absolute inset-0 bg-white/50 dark:bg-slate-800/50 backdrop-blur-sm z-10 flex items-center justify-center">
              <Spinner />
            </div>
            <ContactsTable v-if="contactsList && contactsList.length > 0" :contacts="contactsList" :mandatory-columns="['name', 'phoneNumber', 'companyName', 'location']" :custom-attributes="[]" class="h-full w-full" />
            <div v-else-if="!isFetchingContactCount && !contactsUiFlags.isFetching" class="flex flex-col items-center justify-center h-full text-slate-500">
              <span class="i-lucide-user-x w-12 h-12 mb-3 opacity-20"></span>
              <p>{{ $t('BROADCAST.FILTER_NO_RESULT') }}</p>
            </div>
          </div>
        </div>

        <div class="flex justify-end gap-3 mt-2">
          <button type="button" class="inline-flex justify-center rounded-lg bg-white dark:bg-transparent px-5 py-2.5 text-sm font-semibold text-slate-900 dark:text-slate-300 shadow-sm ring-1 ring-inset ring-slate-300 dark:ring-slate-600 hover:bg-slate-50 dark:hover:bg-slate-700 transition-colors focus:outline-none" @click="goBack">{{ $t('BROADCAST.BTN_CANCEL') }}</button>
          <button type="button" class="inline-flex items-center justify-center space-x-2 bg-green-600 text-white rounded-md hover:bg-green-700 px-6 py-2.5 text-sm font-semibold shadow-sm transition-colors focus:outline-none disabled:opacity-50 disabled:cursor-not-allowed" :disabled="!selectedInbox || totalItems === 0" @click="currentStep = 2">
            <span>{{ $t('BROADCAST.BTN_NEXT') }}</span><svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7"></path></svg>
          </button>
        </div>
      </div>

      <div v-if="currentStep === 2" class="flex flex-col lg:flex-row gap-6 items-start">
        
        <div class="flex-1 w-full bg-white dark:bg-slate-800 rounded-xl shadow-sm border border-slate-200 dark:border-slate-700 overflow-hidden relative">
          <form @submit.prevent="submitBroadcast" class="p-8">
            <div class="mb-8 p-5 bg-blue-50/50 dark:bg-blue-900/10 border border-blue-100 dark:border-blue-800/50 rounded-xl">
              <label class="block text-sm font-semibold text-blue-800 dark:text-blue-300 mb-3 flex items-center gap-2"><span class="i-lucide-book-template w-5 h-5"></span>{{ $t('BROADCAST.TEMPLATE_LABEL') }}</label>
              <multiselect v-model="selectedTemplate" :options="messageTemplates" track-by="id" label="name" :placeholder="$t('BROADCAST.TEMPLATE_PLACEHOLDER')" :searchable="true" :allow-empty="true" select-label="" deselect-label="" class="w-full uniform-dropdown template-dropdown" @select="applyTemplate">
                <template #noResult>{{ $t('BROADCAST.TEMPLATE_NO_RESULT') }}</template>
              </multiselect>
            </div>

            <div class="mb-8">
              <label class="block text-sm font-semibold text-slate-700 dark:text-slate-300 mb-3">{{ $t('BROADCAST.MESSAGE_LABEL') }}</label>
              <div class="mb-3 flex flex-wrap items-center gap-2.5">
                <span class="text-sm font-semibold text-slate-600 dark:text-slate-400 mr-1">{{ $t('BROADCAST.INSERT_VARIABLE') }}</span>
                <button type="button" @click="insertVariable('{{full_name}}')" class="var-chip">{{ $t('BROADCAST.VAR_FULL_NAME') }}</button>
                <button type="button" @click="insertVariable('{{first_name}}')" class="var-chip">{{ $t('BROADCAST.VAR_FIRST_NAME') }}</button>
                <button type="button" @click="insertVariable('{{phone_number}}')" class="var-chip">{{ $t('BROADCAST.VAR_PHONE') }}</button>
              </div>
              <div class="hide-builtin-variables"><MessageEditor v-model="form.message_body" :show-variables="false" /></div>
              <div class="mt-4 flex justify-end">
                <button 
                  type="button" 
                  @click="openTemplateModal" 
                  :disabled="!form.message_body.trim()" 
                  class="inline-flex items-center justify-center space-x-2 bg-green-600 text-white rounded-md hover:bg-green-700 px-5 py-2 text-sm font-semibold shadow-sm transition-colors focus:outline-none disabled:opacity-50 disabled:cursor-not-allowed"
                >
                  <span class="i-lucide-save w-4 h-4"></span>
                  <span>{{ $t('BROADCAST.SAVE_MESSAGE') }}</span>
                </button>
              </div>
            </div>

            <div class="mb-8 p-6 bg-slate-50 dark:bg-slate-900/50 rounded-xl border border-slate-200 dark:border-slate-700">
              <h3 class="text-sm font-bold mb-5 uppercase tracking-wider text-slate-500 dark:text-slate-400 flex items-center gap-2"><span class="i-lucide-settings-2 w-4 h-4"></span>{{ $t('BROADCAST.ADVANCED_SETTINGS') }}</h3>
              <div class="flex flex-col gap-5">
                <label class="flex items-start gap-3 cursor-pointer group">
                  <input type="checkbox" v-model="form.spin_text_enabled" class="mt-0.5 w-4 h-4 text-green-600 rounded border-slate-300 focus:ring-green-600" />
                  <div class="text-sm">
                    <span class="font-medium text-slate-700 dark:text-slate-300 group-hover:text-green-600 transition-colors">{{ $t('BROADCAST.SPIN_TEXT_LABEL') }}</span>
                    <p class="text-slate-500 text-xs mt-1">{{ $t('BROADCAST.SPIN_TEXT_DESC') }}</p>
                  </div>
                </label>
                <label class="flex items-start gap-3 cursor-pointer group">
                  <input type="checkbox" v-model="form.unsubscribe_link_enabled" class="mt-0.5 w-4 h-4 text-green-600 rounded border-slate-300 focus:ring-green-600" />
                  <div class="text-sm">
                    <span class="font-medium text-slate-700 dark:text-slate-300 group-hover:text-green-600 transition-colors">{{ $t('BROADCAST.UNSUBSCRIBE_LABEL') }}</span>
                    <p class="text-slate-500 text-xs mt-1">{{ $t('BROADCAST.UNSUBSCRIBE_DESC') }}</p>
                  </div>
                </label>
              </div>
            </div>

            <div class="flex justify-between items-center pt-6 border-t border-slate-200 dark:border-slate-700">
              <button type="button" class="inline-flex items-center space-x-2 text-slate-600 hover:text-slate-900 dark:text-slate-400 dark:hover:text-slate-200 px-4 py-2 font-medium transition-colors bg-transparent focus:outline-none" @click="currentStep = 1"><svg class="w-4 h-4 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 19l-7-7 7-7"></path></svg>{{ $t('BROADCAST_DETAIL.BACK') }}</button>
              <div class="flex items-center gap-3">
                <button type="button" class="inline-flex items-center space-x-2 border-2 border-red-600 hover:border-red-700 dark:border-red-400 dark:hover:border-red-500 text-red-600 hover:text-red-700 dark:text-red-400 dark:hover:text-red-500 px-4 py-2 rounded-md font-medium transition-colors bg-transparent hover:bg-red-50 dark:hover:bg-red-900/20 focus:outline-none" @click="resetForm"><svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M3 12a9 9 0 1 0 9-9 9.75 9.75 0 0 0-6.74 2.74L3 8"/><path d="M3 3v5h5"/></svg><span>{{ $t('BROADCAST.BTN_RESET') }}</span></button>
                <button type="submit" class="inline-flex items-center justify-center space-x-2 bg-green-600 text-white rounded-md hover:bg-green-700 px-6 py-2 text-sm font-semibold shadow-sm transition-colors focus:outline-none disabled:opacity-50 disabled:cursor-not-allowed" :disabled="isSubmitting || !isFormValid">
                  <svg v-if="isSubmitting" class="animate-spin w-4 h-4" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" aria-hidden="true"><circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle><path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path></svg>
                  <svg v-else class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7"></path></svg>
                  <span>{{ $t('BROADCAST.BTN_SUBMIT') }}</span>
                </button>
              </div>
            </div>
          </form>
        </div>

        <div class="w-full lg:w-[400px] xl:w-[420px] shrink-0 sticky top-6">
          <div class="bg-white dark:bg-slate-800 rounded-xl shadow-sm border border-slate-200 dark:border-slate-700 overflow-hidden flex flex-col h-[calc(100vh-6rem)] min-h-[500px] max-h-[850px]">
            <div class="p-4 border-b border-slate-200 dark:border-slate-700 bg-slate-50 dark:bg-slate-900/50 flex items-center gap-2">
              <span class="i-lucide-smartphone w-5 h-5 text-green-600"></span>
              <h3 class="font-semibold text-slate-800 dark:text-slate-100">{{ $t('BROADCAST.PREVIEW_TITLE') }}</h3>
            </div>
            <div class="flex-1 bg-slate-100 dark:bg-[#0b141a] p-4 flex flex-col items-center justify-center relative overflow-hidden">
              <div class="absolute inset-0 opacity-10 dark:opacity-5 pointer-events-none" style="background-image: url('https://w0.peakpx.com/wallpaper/818/148/HD-wallpaper-whatsapp-background-solid-color-thumbnail.jpg'); background-size: cover;"></div>
              <div class="w-full max-w-[340px] bg-[#efeae2] dark:bg-[#0b141a] border border-slate-300 dark:border-slate-600 rounded-[2rem] overflow-hidden shadow-xl relative z-10 flex flex-col h-full max-h-[600px]">
                <div class="bg-[#00a884] dark:bg-[#202c33] px-4 py-3 flex items-center gap-3 text-white shrink-0">
                  <div class="w-9 h-9 bg-white/20 rounded-full flex items-center justify-center overflow-hidden"><span class="i-lucide-user w-5 h-5"></span></div>
                  <div>
                    <h4 class="font-semibold text-[15px] leading-tight">{{ $t('BROADCAST.PREVIEW_CONTACT_NAME') }}</h4>
                    <p class="text-[11px] opacity-90 mt-0.5">{{ $t('BROADCAST.PREVIEW_ONLINE') }}</p>
                  </div>
                </div>
                
                <div class="flex-1 p-4 overflow-y-auto flex flex-col gap-1.5 relative scrollbar-hide">
                  <div class="bg-[#d9fdd3] dark:bg-[#005c4b] text-[#111b21] dark:text-[#e9edef] p-2.5 pt-2 rounded-lg rounded-tr-none max-w-[92%] self-end shadow-sm relative">
                    <p class="text-[14.2px] whitespace-pre-wrap leading-[1.35] font-sans">{{ formattedPreviewMessage }}</p>
                    <div class="flex items-center justify-end gap-1 mt-1 -mb-1 float-right clear-both ml-3">
                      <span class="text-[11px] text-slate-500 dark:text-[#8696a0]">14:00</span>
                      <span class="i-lucide-check-check w-[14px] h-[14px] text-[#53bdeb]"></span>
                    </div>
                  </div>

                  <div v-if="form.unsubscribe_link_enabled" class="flex flex-col gap-1.5 mt-1 max-w-[92%] self-end w-full">
                    <div class="w-full bg-white dark:bg-[#202c33] text-[#00a884] dark:text-[#00a884] shadow-sm rounded-lg p-2.5 flex items-center justify-center gap-2 cursor-default border border-slate-200/50 dark:border-slate-700/50">
                      <span class="i-lucide-stop-circle w-4 h-4"></span>
                      <span class="text-[14.2px] font-medium">{{ $t('BROADCAST.UNSUBSCRIBE_BTN') }}</span>
                    </div>
                  </div>
                </div>

                <div class="bg-[#f0f2f5] dark:bg-[#202c33] p-2.5 flex items-center gap-2 shrink-0">
                  <div class="flex-1 bg-white dark:bg-[#2a3942] rounded-full h-10 border border-transparent flex items-center px-4"><span class="text-[#8696a0] text-sm">{{ $t('BROADCAST.PREVIEW_INPUT_PLACEHOLDER') }}</span></div>
                  <div class="w-10 h-10 rounded-full bg-[#00a884] flex items-center justify-center text-white shrink-0"><span class="i-lucide-mic w-5 h-5"></span></div>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>

    <transition name="modal-fade">
      <div v-if="showTemplateModal" class="fixed inset-0 z-[100] flex items-center justify-center bg-slate-900/60 backdrop-blur-sm p-4">
        <div class="bg-white dark:bg-slate-800 rounded-xl shadow-2xl w-full max-w-sm overflow-hidden border border-slate-200 dark:border-slate-700">
          <div class="p-5 border-b border-slate-200 dark:border-slate-700 flex justify-between items-center">
            <h3 class="font-bold text-lg text-slate-800 dark:text-white">{{ $t('BROADCAST.MODAL_TPL_TITLE') }}</h3>
            <button @click="closeTemplateModal" class="text-slate-400 hover:text-slate-600 dark:hover:text-slate-200 focus:outline-none">
              <span class="i-lucide-x w-5 h-5 block"></span>
            </button>
          </div>
          <div class="p-5">
            <label class="block text-sm font-medium text-slate-700 dark:text-slate-300 mb-2">{{ $t('BROADCAST.MODAL_TPL_INPUT_LABEL') }}</label>
            <input 
              ref="tplInput" 
              v-model="newTemplateName" 
              type="text" 
              :placeholder="$t('BROADCAST.MODAL_TPL_PLACEHOLDER')" 
              class="w-full px-4 py-2.5 bg-slate-50 dark:bg-slate-900 border border-slate-300 dark:border-slate-600 rounded-lg text-slate-800 dark:text-slate-100 outline-none focus:ring-2 focus:ring-green-600 focus:border-green-600 transition-shadow" 
              @keyup.enter="confirmSaveTemplate"
            >
          </div>
          <div class="p-4 bg-slate-50 dark:bg-slate-900/50 flex justify-end gap-3 border-t border-slate-200 dark:border-slate-700">
            <button @click="closeTemplateModal" class="inline-flex justify-center rounded-lg bg-white dark:bg-transparent px-4 py-2 text-sm font-semibold text-slate-900 dark:text-slate-300 shadow-sm ring-1 ring-inset ring-slate-300 dark:ring-slate-600 hover:bg-slate-50 dark:hover:bg-slate-700 transition-colors focus:outline-none">
              {{ $t('BROADCAST.BTN_CANCEL') }}
            </button>
            <button @click="confirmSaveTemplate" :disabled="!newTemplateName.trim()" class="inline-flex w-full justify-center bg-green-600 text-white rounded-md hover:bg-green-700 px-4 py-2 text-sm font-semibold shadow-sm sm:w-auto transition-colors disabled:opacity-50 focus:outline-none">
              {{ $t('BROADCAST.MODAL_TPL_BTN_CONFIRM') }}
            </button>
          </div>
        </div>
      </div>
    </transition>

    <transition name="modal-fade">
      <div v-if="showSegmentModal" class="fixed inset-0 z-[100] flex items-center justify-center bg-slate-900/60 backdrop-blur-sm p-4">
        <div class="bg-white dark:bg-slate-800 rounded-xl shadow-2xl w-full max-w-sm overflow-hidden border border-slate-200 dark:border-slate-700">
          <div class="p-5 border-b border-slate-200 dark:border-slate-700 flex justify-between items-center">
            <h3 class="font-bold text-lg text-slate-800 dark:text-white">{{ $t('BROADCAST.MODAL_SEGMENT_TITLE') }}</h3>
            <button @click="showSegmentModal = false" class="text-slate-400 hover:text-slate-600 dark:hover:text-slate-200 focus:outline-none">
              <span class="i-lucide-x w-5 h-5 block"></span>
            </button>
          </div>
          <div class="p-5">
            <label class="block text-sm font-medium text-slate-700 dark:text-slate-300 mb-2">{{ $t('BROADCAST.MODAL_SEGMENT_LABEL') }}</label>
            <input
              v-model="newSegmentName"
              type="text"
              :placeholder="$t('BROADCAST.MODAL_SEGMENT_PLACEHOLDER')"
              class="w-full px-4 py-2.5 bg-slate-50 dark:bg-slate-900 border border-slate-300 dark:border-slate-600 rounded-lg text-slate-800 dark:text-slate-100 outline-none focus:ring-2 focus:ring-green-600 focus:border-green-600 transition-shadow"
              @keyup.enter="confirmSaveSegment"
            >
            <p class="text-xs text-slate-500 mt-2">{{ $t('BROADCAST.MODAL_SEGMENT_HINT') }}</p>
          </div>
          <div class="p-4 bg-slate-50 dark:bg-slate-900/50 flex justify-end gap-3 border-t border-slate-200 dark:border-slate-700">
            <button @click="showSegmentModal = false" class="inline-flex justify-center rounded-lg bg-white dark:bg-transparent px-4 py-2 text-sm font-semibold text-slate-900 dark:text-slate-300 shadow-sm ring-1 ring-inset ring-slate-300 dark:ring-slate-600 hover:bg-slate-50 dark:hover:bg-slate-700 transition-colors focus:outline-none">
              {{ $t('BROADCAST.BTN_CANCEL') }}
            </button>
            <button @click="confirmSaveSegment" :disabled="!newSegmentName.trim() || isSavingSegment" class="inline-flex w-full justify-center bg-green-600 text-white rounded-md hover:bg-green-700 px-4 py-2 text-sm font-semibold shadow-sm sm:w-auto transition-colors disabled:opacity-50 focus:outline-none flex items-center gap-2">
              <svg v-if="isSavingSegment" class="animate-spin w-4 h-4" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24"><circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle><path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path></svg>
              <span>{{ $t('BROADCAST.MODAL_SEGMENT_BTN_CONFIRM') }}</span>
            </button>
          </div>
        </div>
      </div>
    </transition>

  </div>
</template>

<script>
import { mapGetters } from 'vuex';
import Multiselect from 'vue-multiselect';
import MessageEditor from './components/MessageEditor.vue';
import ContactFilterBroadcast from './components/ContactFilterBroadcast.vue';
import ContactsTable from 'dashboard/components-next/Contacts/ContactsTable/ContactsTable.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import filterQueryGenerator from 'dashboard/helper/filterQueryGenerator';
import { debounce } from '@chatwoot/utils';

export default {
  name: 'BroadcastForm',
  components: { MessageEditor, Multiselect, ContactFilterBroadcast, ContactsTable, Spinner },

  data() {
    return {
      currentStep: 1,
      targetMode: 'dropdown',
      isSubmitting: false,
      
      showTemplateModal: false,
      newTemplateName: '',

      showSegmentModal: false,
      newSegmentName: '',
      isSavingSegment: false,

      selectedInbox: null,
      selectedSegment: { id: 'all', name: this.$t('BROADCAST.ALL_CONTACTS'), query: null },
      selectedTemplate: null,
      form: {
        message_body: '',
        spin_text_enabled: false,
        unsubscribe_link_enabled: false,
      },
      activeFilterPayload: null,
      estimatedContactCount: null,
      isFetchingContactCount: false,
    };
  },

  computed: {
    ...mapGetters({
      inboxes: 'inboxes/getInboxes',
      contactsList: 'contacts/getContactsList',
      contactsUiFlags: 'contacts/getUIFlags',
      contactsMeta: 'contacts/getMeta',
      contactSegments: 'customViews/getContactCustomViews',
      savedTemplates: 'broadcastTemplates/getTemplates',
    }),
    messageTemplates() {
      return this.savedTemplates.map(tpl => ({
        id: tpl.id,
        name: `${tpl.name}`,
        content: tpl.message_body
      }));
    },

    whatsappInboxes() { return this.inboxes.filter(inbox => ['Channel::Whatsapp', 'Channel::WhatsappUnofficial', 'Channel::Api'].includes(inbox.channel_type)); },
    
    segmentOptions() {
      const allOption = { id: 'all', name: this.$t('BROADCAST.ALL_CONTACTS'), query: null };
      if (this.contactSegments && this.contactSegments.length > 0) {
        return [allOption, ...this.contactSegments];
      }
      return [allOption];
    },

    isFormValid() { return this.selectedInbox !== null && this.form.message_body.trim() !== ''; },
    totalItems() { return this.estimatedContactCount !== null ? this.estimatedContactCount : (this.contactsMeta?.count ?? this.contactsList.length); },
    
    formattedPreviewMessage() {
      let text = this.form.message_body;
      if (!text?.trim()) return this.$t('BROADCAST.PREVIEW_EMPTY');

      if (this.form.spin_text_enabled) {
        text = text.replace(/\[([^\[\]]+)\]/g, (_, group) => group.split('|')[0]);
      }
      text = text.replace(/\{\{full_name\}\}/g, 'John Doe').replace(/\{\{first_name\}\}/g, 'John').replace(/\{\{phone_number\}\}/g, '+1234567890');

      return text;
    },
  },

  created() {
    this.debouncedFetchCount = debounce(async (filterData, isPrebuiltQuery = false) => {
      this.isFetchingContactCount = true;
      try {
        if (!filterData || (Array.isArray(filterData) && filterData.length === 0)) {
          await this.$store.dispatch('contacts/get', { page: 1 });
          this.estimatedContactCount = this.contactsMeta?.count ?? null;
        } else {
          const queryPayload = isPrebuiltQuery ? filterData : filterQueryGenerator(filterData);
          const { data } = await this.$store.dispatch('contacts/filter', { page: 1, queryPayload });
          this.estimatedContactCount = data?.meta?.count ?? null;
        }
      } catch { this.estimatedContactCount = 0; } finally { this.isFetchingContactCount = false; }
    }, 400);
  },
  
  mounted() { 
    this.$store.dispatch('inboxes/get'); 
    this.$store.dispatch('contacts/get', { page: 1 }); 
    this.$store.dispatch('customViews/get', 1);
    this.$store.dispatch('broadcastTemplates/get');
  },

  methods: {
    goBack() { this.$router.push({ name: 'blasting_index' }); },
    resetForm() { this.form = { message_body: '', spin_text_enabled: false, unsubscribe_link_enabled: false }; this.selectedTemplate = null; },
    
    cancelCustomMode() {
      this.targetMode = 'dropdown';
      this.onSegmentSelect(this.selectedSegment); 
    },
    onSegmentSelect(selectedOption) {
      if (selectedOption.id === 'all') {
        this.debouncedFetchCount(null, false);
      } else {
        this.debouncedFetchCount(selectedOption.query, true);
      }
    },
    onFilterChange(rawPayload) { 
      this.activeFilterPayload = rawPayload; 
      this.debouncedFetchCount(rawPayload, false); 
    },

    openSegmentModal() {
      this.newSegmentName = '';
      this.showSegmentModal = true;
    },
    async confirmSaveSegment() {
      if (!this.newSegmentName.trim() || !this.activeFilterPayload) return;
      
      this.isSavingSegment = true;
      try {
        const newSegmentQuery = filterQueryGenerator(this.activeFilterPayload);
        const response = await this.$store.dispatch('customViews/create', {
          name: this.newSegmentName,
          filter_type: 1,
          query: newSegmentQuery
        });
        
        if (window.bus) window.bus.$emit('new-toast-message', this.$t('BROADCAST.SEGMENT_SAVED'));
        
        this.targetMode = 'dropdown';
        if (response && response.data) {
           this.selectedSegment = response.data;
           this.onSegmentSelect(this.selectedSegment);
        }
        
        this.showSegmentModal = false;
        this.newSegmentName = '';
      } catch (error) {
        if (window.bus) window.bus.$emit('new-toast-message', this.$t('BROADCAST.SEGMENT_ERROR'));
      } finally {
        this.isSavingSegment = false;
      }
    },

    applyTemplate(opt) { if (opt) this.form.message_body = opt.content; },
    insertVariable(variableStr) {
      const body = this.form.message_body;
      const needsLeadingSpace = body.length > 0 && !body.endsWith(' ') && !body.endsWith('\n');
      this.form.message_body = body + (needsLeadingSpace ? ' ' : '') + variableStr + ' ';
    },
    openTemplateModal() { this.newTemplateName = ''; this.showTemplateModal = true; this.$nextTick(() => this.$refs.tplInput?.focus()); },
    closeTemplateModal() { this.showTemplateModal = false; },
    async confirmSaveTemplate() {
      const name = this.newTemplateName.trim();
      if (!name) return;

      try {
        const payload = {
          name: name,
          message_body: this.form.message_body
        };
        
        const newTpl = await this.$store.dispatch('broadcastTemplates/create', payload);
        
        if (window.bus) window.bus.$emit('new-toast-message', this.$t('BROADCAST.TEMPLATE_SAVED_TOAST', { name: name }));
        
        this.selectedTemplate = {
          id: newTpl.id,
          name: `${newTpl.name}`,
          content: newTpl.message_body
        };
        
        this.closeTemplateModal();
      } catch (error) {
        if (window.bus) window.bus.$emit('new-toast-message', 'Gagal menyimpan template pesan.');
      }
    },

    async submitBroadcast() {
      if (!this.isFormValid) return;
      this.isSubmitting = true;
      try {
        let finalSegmentQuery = null;

        if (this.targetMode === 'dropdown') {
           if (this.selectedSegment.id !== 'all') {
             finalSegmentQuery = JSON.stringify(this.selectedSegment.query);
           } else {
             finalSegmentQuery = 'all';
           }
        } else {
           if (this.activeFilterPayload && this.activeFilterPayload.length > 0) {
             finalSegmentQuery = JSON.stringify(filterQueryGenerator(this.activeFilterPayload));
           } else {
             finalSegmentQuery = 'all';
           }
        }

        const payload = {
          inbox_id: this.selectedInbox.id,
          message_body: this.form.message_body,
          spin_text_enabled: this.form.spin_text_enabled,
          unsubscribe_link_enabled: this.form.unsubscribe_link_enabled,
          target_segment: finalSegmentQuery,
        };
        
        await this.$store.dispatch('broadcasts/create', payload);
        if (window.bus) window.bus.$emit('new-toast-message', this.$t('BROADCAST.SUCCESS_MESSAGE'));
        this.goBack();
      } catch {
        if (window.bus) window.bus.$emit('new-toast-message', this.$t('BROADCAST.ERROR_MESSAGE'));
      } finally { this.isSubmitting = false; }
    }
  }
};
</script>

<style scoped>
  .modal-fade-enter-active, .modal-fade-leave-active { transition: opacity 0.2s ease, transform 0.2s ease; }
  .modal-fade-enter, .modal-fade-leave-to { opacity: 0; transform: scale(0.95); }
  .var-chip { @apply px-3 py-1.5 text-xs font-medium bg-transparent border border-slate-300 dark:border-slate-600 rounded-md text-slate-700 dark:text-slate-300 hover:bg-slate-100 dark:hover:bg-slate-800 transition-colors focus:outline-none; }
  .custom-scrollbar::-webkit-scrollbar { width: 8px; }
  .custom-scrollbar::-webkit-scrollbar-track { background: transparent; }
  .custom-scrollbar::-webkit-scrollbar-thumb { background-color: #cbd5e1; border-radius: 20px; }
  .dark .custom-scrollbar::-webkit-scrollbar-thumb { background-color: #475569; }
  .uniform-dropdown { @apply text-sm text-slate-700 dark:text-slate-200; }
  :deep(.uniform-dropdown .multiselect__tags) { @apply bg-white dark:bg-slate-900 border-slate-300 dark:border-slate-600 rounded-lg; min-height: 44px; padding-top: 10px; padding-bottom: 10px; }
  :deep(.uniform-dropdown .multiselect__input) { @apply bg-transparent dark:text-white pt-0.5; }
  :deep(.uniform-dropdown .multiselect__single) { @apply bg-transparent dark:text-white mt-0.5; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; max-width: 90%; }
  :deep(.uniform-dropdown .multiselect__content-wrapper) { @apply bg-white dark:bg-slate-800 border-slate-300 dark:border-slate-600 z-50 rounded-lg shadow-lg mt-1; }
  :deep(.template-dropdown .multiselect__tags) { border-color: #16a34a; }
  :deep(.multiselect__option--highlight) { background-color: #16a34a !important; color: #ffffff !important; }
  :deep(.multiselect__option--selected.multiselect__option--highlight) { background-color: #15803d !important; }
  .scrollbar-hide::-webkit-scrollbar { display: none; }
  .scrollbar-hide { -ms-overflow-style: none; scrollbar-width: none; }
  :deep(.hide-builtin-variables label), :deep(.hide-builtin-variables .variables-container), :deep(.hide-builtin-variables .toolbar), :deep(.hide-builtin-variables .flex.gap-2) { display: none !important; }
  .preview-table-container :deep(table th:last-child), .preview-table-container :deep(table td:last-child) { display: none !important; }
</style>
}