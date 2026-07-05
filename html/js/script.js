let translation = {};

var number = Intl.NumberFormat('en-US', {minimumFractionDigits: 0});
String.prototype.format = function() {
    var formatted = this;
    for (var i = 0; i < arguments.length; i++) {
        var regexp = new RegExp('\\{'+i+'\\}', 'gi');
        formatted = formatted.replace(regexp, arguments[i]);
    }
    return formatted;
};


// UI Variables:
let currentMenu = null;
let currentSubMenu = null;
var isMenuOpened = false;

let documentsList = null;
let photosList = null;
let ownedDocumentsList = null;
let isSelectingPhoto = false;
let canPressAgain = true;

let licensesNames = [];



// ==========================================================
// RealRPG ID Card - 3D flip view for id_card
// ==========================================================
function rrVal(data, keys, fallback = '-') {
    if (!data) return fallback;
    for (const key of keys) {
        if (data[key] !== undefined && data[key] !== null && String(data[key]).trim() !== '') {
            return String(data[key]).trim();
        }
    }
    return fallback;
}

function rrUpper(value, fallback = '-') {
    const text = String(value ?? '').trim();
    return (text.length ? text : fallback).toLocaleUpperCase('hu-HU');
}

function rrPrettyDate(value, fallback = '-') {
    const text = String(value ?? '').trim();
    if (!text) return fallback;
    return text;
}

function rrToday() {
    const d = new Date();
    return `${d.getFullYear()}. ${String(d.getMonth()+1).padStart(2, '0')}. ${String(d.getDate()).padStart(2, '0')}.`;
}

function rrExpiry() {
    const d = new Date();
    d.setFullYear(d.getFullYear() + 5);
    return `${d.getFullYear()}. ${String(d.getMonth()+1).padStart(2, '0')}. ${String(d.getDate()).padStart(2, '0')}.`;
}

function rrGender(value) {
    const raw = String(value ?? '').trim().toLowerCase();
    if (['m', 'male', 'ferfi', 'férfi', 'man'].includes(raw)) return 'FÉRFI';
    if (['f', 'female', 'no', 'nő', 'woman'].includes(raw)) return 'NŐ';
    return raw ? raw.toLocaleUpperCase('hu-HU') : 'NINCS MEGADVA';
}

function rrNormalizeMrz(value) {
    return String(value ?? '')
        .normalize('NFD')
        .replace(/[\u0300-\u036f]/g, '')
        .toUpperCase()
        .replace(/[^A-Z0-9]/g, '<')
        .replace(/<+/g, '<');
}

function rrPadMrz(value, len) {
    value = rrNormalizeMrz(value);
    if (value.length > len) return value.substring(0, len);
    return value.padEnd(len, '<');
}

function rrSet(selector, value, fallback = '-') {
    const text = String(value ?? '').trim();
    $(selector).text(text.length ? text : fallback);
}

function rrSetHtmlLines(selector, value, fallback = '-') {
    const text = String(value ?? '').trim() || fallback;
    const safe = escapeHtml(text).replace(/\n/g, '<br>');
    $(selector).html(safe);
}

function showRealRpgFlipIdCard(item) {
    const data = item.data || {};
    const firstName = rrVal(data, ['firstName', 'firstname', 'first_name', 'keresztnev'], '');
    const lastName = rrVal(data, ['lastName', 'lastname', 'last_name', 'vezeteknev'], '');
    const fullName = rrVal(data, ['fullName', 'name'], `${lastName} ${firstName}`.trim() || 'Kovács Benjamin');
    const documentId = rrVal(data, ['document_id', 'documentId', 'serialNumber', 'serial', 'id'], 'RR-24-07-9821');
    const birth = rrPrettyDate(rrVal(data, ['dateOfBirth', 'birthdate', 'dob', 'szuletesiDatum'], '1998. 07. 24.'));
    const gender = rrGender(rrVal(data, ['gender', 'sex', 'nem'], 'férfi'));
    const nationality = rrUpper(rrVal(data, ['nationality', 'allampolgarsag'], 'Magyar'));
    const address = rrVal(data, ['address', 'lakcim', 'residence'], '1013 Budapest\nAttila út 45. 2/3.');
    const issued = rrVal(data, ['issuedAt', 'issueDate', 'createdAt', 'created'], rrToday());
    const expiry = rrVal(data, ['validUntil', 'expireDate', 'expires', 'expiry'], rrExpiry());
    const signature = rrVal(data, ['signature'], fullName);
    const ssn = rrVal(data, ['ssn', 'citizenid', 'identifier'], documentId);

    rrSet('#rr-id-fullname', rrUpper(fullName));
    rrSet('#rr-id-birth', birth);
    rrSet('#rr-id-gender', gender);
    rrSet('#rr-id-nationality', nationality);
    rrSet('#rr-id-number', documentId);
    rrSet('#rr-id-signature', signature);
    rrSetHtmlLines('#rr-id-address', rrUpper(address));
    rrSet('#rr-id-issued', issued);
    rrSet('#rr-id-expiry', expiry);
    rrSet('#rr-id-barcode-text', documentId);
    rrSetHtmlLines('#rr-id-issuer', 'REALRPG ADMINISZTRÁCIÓ\n<span>IDENTITY MANAGEMENT DIVISION</span>');

    const photo = String(item.photo || '').trim();
    $('#rr-id-photo').attr('src', photo.length ? photo : './images/realrpg_photo_placeholder.svg');

    const mrzName = rrPadMrz(`RREALRPG<<${lastName || fullName}<<${firstName}`, 44);
    const mrzDocument = rrPadMrz(`${documentId}HUN${birth}${gender.substring(0, 1)}${expiry}${ssn}`, 44);
    const mrzAddress = rrPadMrz(address, 44);
    $('#rr-id-mrz-1').text(mrzName);
    $('#rr-id-mrz-2').text(mrzDocument);
    $('#rr-id-mrz-3').text(mrzAddress);

    $('.documents').hide();
    $('.badges').hide();
    $('.help').hide();
    $('.rr-id-flip-card').removeClass('is-flipped');
    $('.rr-id-flip-shell').css('display', 'flex').hide().fadeIn(120);
}

$(document).on('click', '.rr-id-flip-card', function() {
    $(this).toggleClass('is-flipped');
});

function escapeHtml(value) {
    return String(value ?? '')
        .replace(/&/g, '&amp;')
        .replace(/</g, '&lt;')
        .replace(/>/g, '&gt;')
        .replace(/"/g, '&quot;')
        .replace(/'/g, '&#039;');
}


$(document).on('keydown', 'body', function(e) {
    if (e.which == 27) {
        if (isSelectingPhoto) {
            isSelectingPhoto = false;
            $('.documents-menu div[data-type="licenses"]>div>.side-boxes>.box[data-type="documents"]').removeAttr('style');
            $('.documents-menu div[data-type="licenses"]>div>.side-boxes>.box[data-type="owned-documents"]').removeAttr('style');
            
            $('.documents-menu div[data-type="licenses"]>div>.side-boxes>.box[data-type="documents"]').css({
                'opacity': '1.0',
                'filter': 'blur(0px)'
            });

            $('.documents-menu div[data-type="licenses"]>div>.side-boxes>.box[data-type="owned-documents"]').css({
                'opacity': '1.0',
                'filter': 'blur(0px)'
            });

            $('.documents-menu div[data-type="licenses"]>div>.side-boxes>.box[data-type="photos"] .photos-list #select-photo').hide();
            $('.documents-menu div[data-type="licenses"]>div>.side-boxes>.box[data-type="photos"] .photos-list #remove-photo').fadeIn(120);
            return;
        }
        
        $.post(`https://${GetParentResourceName()}/close`, JSON.stringify({menu: currentMenu}));
        isMenuOpened = false;
    }
})

window.addEventListener("load", function() {
    $.post(`https://${GetParentResourceName()}/loaded`)
})

window.addEventListener('message', function(event) {
    var item = event.data;
    if (item.action == "loaded") {
        let lang = item.lang;

        licensesNames = item.documentsNames;

        $.ajax({
            url: '../config/translation.json',
            type: 'GET',
            dataType: 'json',
            success: function (code, statut) {
                if (!code[lang]) {
                    translation = code["EN"];
                    console.warn(`^7Selected language ^1"${lang}"^7 not found, changed to ^2"EN"^7, configure your language in translation.json.`);
                } else {
                    translation = code[lang];
                }
                
                $('.documents > #header .title').html(translation.document_title);
                $('.badges > #header > .title').html(translation.document_title);

                $('.help').html(translation.hint_close);
                
                $('.documents-menu .header > .name').text(translation.documents_menu.menu_title);

                $('.documents-menu div[data-type="licenses"]>div>.side-boxes>.box[data-type="documents"] .header').text(translation.documents_menu.documents_list.header);
                $('.documents-menu div[data-type="licenses"]>div>.side-boxes>.box[data-type="documents"] .title').text(translation.documents_menu.documents_list.title);

                $('.documents-menu div[data-type="licenses"]>div>.side-boxes>.box[data-type="photos"] .header').text(translation.documents_menu.photos_list.header);
                $('.documents-menu div[data-type="licenses"]>div>.side-boxes>.box[data-type="photos"] .title').text(translation.documents_menu.photos_list.title);

                $('.documents-menu div[data-type="licenses"]>div>.side-boxes>.box[data-type="owned-documents"] .header').text(translation.documents_menu.owned_documents_list.header);
                $('.documents-menu div[data-type="licenses"]>div>.side-boxes>.box[data-type="owned-documents"] .title').text(translation.documents_menu.owned_documents_list.title);

                $('.check_document_menu .header > .name').text(translation.check_document.header);
                $('.check_document_menu #find > span').text(translation.check_document.enter_serial);
                $('.check_document_menu #find > .search > p').text(translation.check_document.search_btn);
                $('.check_document_menu #loading > p').text(translation.check_document.searching_for_information);
            }
        });
    } else if (item.action == "compressPhoto") {
        var base64Image = item.base64;
        convertPngToWebp(base64Image).then(webpBase64 => {
            $.post(`https://${GetParentResourceName()}/compressedPhoto`, JSON.stringify({compressedBase64: webpBase64, documentName: item.documentName, cancelCurrentActive: item.cancelCurrentActive}));
        }).catch(error => {
            console.error(error);
        });
    } else if (item.action == "showDocument") {
        if (item.type == "document" && item.name == "id_card") {
            showRealRpgFlipIdCard(item);
            return;
        }
        let loadedData = documentValues(item.name, item.data);
        
        let data = ''
        let data2 = ''
        let signature = ''
        let document_name = ''

        loadedData.forEach(val => {
            if (val.type == "data") {
                if (item.type == "badge") {
                    data += `
                        <div>
                            <div class="value">${escapeHtml(val.value)}</div>
                            <div class="label">${escapeHtml(val.label)}</div>
                        </div>
                    `
                } else {
                    data += `
                        <div>
                            <div class="label">${escapeHtml(val.label)}</div>
                            <div class="value">${escapeHtml(val.value)}</div>
                        </div>
                    `
                }
            } else if (val.type == "data2") {
                data2 += `
                    <div>
                        <div class="label">${escapeHtml(val.label)}</div>
                        <div class="value">${escapeHtml(val.value)}</div>
                    </div>
                `
            } else if (val.type == "signature") {
                signature = escapeHtml(val.value)
            } else if (val.type == "document_name") {
                document_name = escapeHtml(val.value)
            }
        });
        
        if (item.type == "document") {
            // ══════════════════════════════════════════════════════════════
            // REALRPG EGYEDI ID KÁRTYA: ha az item 'id_card', a saját
            // .rr-id-flip-shell NUI-t használjuk (3D flip, egyedi design)
            // ══════════════════════════════════════════════════════════════
            if (item.name === 'id_card') {
                // Mezők kitöltése a metadata-ból
                let fullName = ((data['firstName'] || '') + ' ' + (data['lastName'] || '')).trim().toUpperCase();
                let birth = data['dateOfBirth'] || '';
                let gender = data['gender'] || data['sex'] || 'N/A';
                let nationality = (data['nationality'] || 'N/A').toUpperCase();
                let serial = data['document_id'] || '';
                let signature = (data['firstName'] || '') + ' ' + (data['lastName'] || '');

                $('#rr-id-fullname').text(fullName || 'ISMERETLEN');
                $('#rr-id-birth').text(birth || 'N/A');
                $('#rr-id-gender').text(gender.toUpperCase());
                $('#rr-id-nationality').text(nationality);
                $('#rr-id-number').text(serial || 'N/A');
                $('#rr-id-signature').text(signature || '');
                $('#rr-id-barcode-text').text(serial || '');

                // MRZ sorok generálása
                let mrzName = ('RREALRPG<<' + (data['lastName'] || 'UNKNOWN') + '<<' + (data['firstName'] || 'UNKNOWN')).toUpperCase().replace(/\s/g, '<');
                while (mrzName.length < 44) mrzName += '<';
                mrzName = mrzName.substring(0, 44);
                $('#rr-id-mrz-1').text(mrzName);

                let mrzSerial = (serial || 'RR00000000').replace(/-/g, '');
                let mrz2 = mrzSerial + 'HUN' + (birth || '000000').replace(/\D/g, '').substring(0,6) + 'M<<<<<<4';
                while (mrz2.length < 44) mrz2 += '<';
                mrz2 = mrz2.substring(0, 44);
                $('#rr-id-mrz-2').text(mrz2);

                // Fotó beállítása ha van
                if (item.photo) {
                    $('#rr-id-photo').attr('src', item.photo);
                } else {
                    $('#rr-id-photo').attr('src', './images/realrpg_photo_placeholder.svg');
                }

                // Flip reset és megjelenítés
                $('.rr-id-flip-card').removeClass('is-flipped');
                $('.rr-id-flip-shell').css('display', 'flex').hide().fadeIn(200);

                // Help hint
                $('.help').css({ top: '90%', width: '100%' });
                $('.help').html('Kattints a kártyára a megfordításhoz • ESC bezárás');
                $('.help').fadeIn(120);
                return;
            }

            // ══════════════════════════════════════════════════════════════
            // Eredeti VMS dokumentum megjelenítés (driving_license, stb.)
            // ══════════════════════════════════════════════════════════════
            $(".documents > #header > .document_name").html(document_name)
            $(".documents > #data").html(data)
            $(".documents > #signature > p").html(signature)
    
            $(".documents > #document-photo").attr("src", item.photo);
            $(".documents > #document-photo-mini").attr("src", item.photo);
            $(".documents > #document-image").attr("src", `./images/${item.image}`);
            
            $('.help').css({
                top: '33.5em',
                width: '30em',
            })

            $('.documents').fadeIn(120);
        } else if (item.type == "badge") {
            $(".badges > #header > .badge_name").html(document_name)
            $(".badges > #data").html(data)
            $(".badges > #data2").html(data2)
            $(".badges > #signature > p").html(signature)
            $(".badges > .badge-icon").attr("src", `./images/${item.badgeImage}`);
            $(".badges > #badge-photo").attr("src", item.photo);
            $(".badges > #document-image").attr("src", `./images/${item.image}`);
            
            $('.help').css({
                top: '44.5em',
                width: '45em',
            })

            $('.badges').fadeIn(120);
        }
        $('.help').fadeIn(120);

    } else if (item.action == "closeDocument") {
        $('.documents').fadeOut(120);
        $('.badges').fadeOut(120);
        $('.rr-id-flip-shell').fadeOut(120);
        $('.help').fadeOut(120);
    } else if (item.action == "openDocumentsMenu") {
        currentMenu = 'documents_menu';

        documentsList = item.documentsList;

        $('.documents-menu div[data-type="licenses"]>div>.side-boxes>.box[data-type="documents"] div[class="licenses-list"] > div').html(LoadLicenses(documentsList));
        photosList = item.ownedPhotos;
        ownedDocumentsList = item.ownedDocuments;
        LoadOwnedDocumentPhotos(photosList);
        LoadOwnedDocuments(ownedDocumentsList);
        $('.documents-menu').css('display', 'flex');
        $('.documents-menu > div').fadeIn(120);

    } else if (item.action == "closeDocumentsMenu") {
        $('.documents-menu > div').fadeOut(120);
        
        isSelectingPhoto = false;
        $('.documents-menu div[data-type="licenses"]>div>.side-boxes>.box[data-type="documents"]').removeAttr('style');
        $('.documents-menu div[data-type="licenses"]>div>.side-boxes>.box[data-type="owned-documents"]').removeAttr('style');
        
        $('.documents-menu div[data-type="licenses"]>div>.side-boxes>.box[data-type="documents"]').css({
            'opacity': '1.0',
            'filter': 'blur(0px)'
        });

        $('.documents-menu div[data-type="licenses"]>div>.side-boxes>.box[data-type="owned-documents"]').css({
            'opacity': '1.0',
            'filter': 'blur(0px)'
        });

        $('.documents-menu div[data-type="licenses"]>div>.side-boxes>.box[data-type="photos"] .photos-list #select-photo').hide();
        $('.documents-menu div[data-type="licenses"]>div>.side-boxes>.box[data-type="photos"] .photos-list #remove-photo').fadeIn(120);

        currentMenu = null;

    } else if (item.action == "updateDocumentsMenu") {
        if (item.ownedPhotos) {
            photosList = item.ownedPhotos;
            LoadOwnedDocumentPhotos(photosList);
        }
        if (item.ownedDocuments) {
            ownedDocumentsList = item.ownedDocuments;
            LoadOwnedDocuments(ownedDocumentsList);
        }
    } else if (item.action == "openCheckDocumentsMenu") {
        currentMenu = 'check_document_menu';

        $('.check_document_menu #find input').val('');
        $('.check_document_menu #find').show();
        $('.check_document_menu #loading').hide();

        $('.check_document_menu').css('display', 'flex');
        $('.check_document_menu > div').fadeIn(120);

    } else if (item.action == "closeCheckDocumentsMenu") {
        $('.check_document_menu').fadeOut(120);
        currentMenu = null;
        
    } else if (item.action == "updateCheckDocumentsMenu") {
        $('.check_document_menu #find input').val('');

    }
});

$(".close").click(() => {
    $.post(`https://${GetParentResourceName()}/close`, JSON.stringify({menu: currentMenu}));
    isMenuOpened = false;
    currentMenu = null;
    currentSubMenu = null;
})

// ═══ RealRPG ID Card: kattintásra flip ═══
$(document).on('click', '.rr-id-flip-card', function() {
    $(this).toggleClass('is-flipped');
});

function convertPngToWebp(pngBase64, quality = 1.0) {
    return new Promise((resolve, reject) => {
        const img = new Image();
        img.src = pngBase64;

        img.onload = () => {
            const canvas = document.createElement('canvas');
            canvas.width = img.width;
            canvas.height = img.height;

            const ctx = canvas.getContext('2d');
            ctx.drawImage(img, 0, 0);

            const webpBase64 = canvas.toDataURL('image/webp', quality);
            resolve(webpBase64);
        };

        img.onerror = reject;
    });
}

function orderDocument(name) {
    if (isSelectingPhoto) return;
    if (!canPressAgain) return;
    canPressAgain = false;
    
    isSelectingPhoto = name;
    $('.documents-menu div[data-type="licenses"]>div>.side-boxes>.box[data-type="documents"]').css({
        'opacity': '0.1',
        'filter': 'blur(2px)'
    });

    $('.documents-menu div[data-type="licenses"]>div>.side-boxes>.box[data-type="owned-documents"]').css({
        'opacity': '0.1',
        'filter': 'blur(2px)'
    });

    $('.documents-menu div[data-type="licenses"]>div>.side-boxes>.box[data-type="photos"] .photos-list #select-photo').fadeIn(120);
    $('.documents-menu div[data-type="licenses"]>div>.side-boxes>.box[data-type="photos"] .photos-list #remove-photo').hide();


    setTimeout(() => {
        canPressAgain = true;
    }, 2000);
}

function removePhoto(id) {
    if (isSelectingPhoto) return;
    $.post(`https://${GetParentResourceName()}/removePhoto`, JSON.stringify({id: id}));
}

function selectDocumentPhoto(id) {
    if (!isSelectingPhoto) return;
    $.post(`https://${GetParentResourceName()}/orderDocument`, JSON.stringify({name: isSelectingPhoto, photoId: id}));
    isSelectingPhoto = false;
    $('.documents-menu div[data-type="licenses"]>div>.side-boxes>.box[data-type="documents"]').removeAttr('style');
    $('.documents-menu div[data-type="licenses"]>div>.side-boxes>.box[data-type="owned-documents"]').removeAttr('style');
    
    $('.documents-menu div[data-type="licenses"]>div>.side-boxes>.box[data-type="documents"]').css({
        'opacity': '1.0',
        'filter': 'blur(0px)'
    });

    $('.documents-menu div[data-type="licenses"]>div>.side-boxes>.box[data-type="owned-documents"]').css({
        'opacity': '1.0',
        'filter': 'blur(0px)'
    });

    $('.documents-menu div[data-type="licenses"]>div>.side-boxes>.box[data-type="photos"] .photos-list #select-photo').hide();
    $('.documents-menu div[data-type="licenses"]>div>.side-boxes>.box[data-type="photos"] .photos-list #remove-photo').fadeIn(120);
}

function invalidateDocument(serialNumber) {
    if (isSelectingPhoto) return;
    $.post(`https://${GetParentResourceName()}/invalidateDocument`, JSON.stringify({serialNumber: serialNumber}));
}

$(".check_document_menu #find .search").click(() => {
    $('.check_document_menu #find').hide();
    $('.check_document_menu #loading').fadeIn(120);

    setTimeout(() => {
        if (currentMenu && currentMenu == 'check_document_menu') {
            let serialNumber = $('.check_document_menu .menu > #find > input').val();
            $.post(`https://${GetParentResourceName()}/getInfoBySerialNumber`, JSON.stringify({serialNumber: serialNumber}), function(info) {
                $('.check_document_menu #find').show();
                $('.check_document_menu #loading').hide();
            });
        }
    }, 4000);
})