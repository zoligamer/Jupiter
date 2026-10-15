import 'dart:async';
import 'dart:convert' as conv;
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:jupiter/API/ics_calendar.dart';
import 'package:jupiter/Misc/clickable_text_span.dart';
import 'package:jupiter/colors.dart';
import 'package:jupiter/language.dart';
import '../storage.dart' as storage;
import 'dart:developer' as debug;
import '../storage.dart';
  
  class URLs{
    static const String INSTITUTIONS_URL = "https://mobilecloudservice.cloudapp.net/MobileServiceLib/MobileCloudService.svc/GetAllNeptunMobileUrls";
    static const String TRAININGS_URL = "/api/GetTrainings";
    static const String CALENDAR_URL = "/api/GetCalendarData";
    static const String PERIODTERMS_URL = "/api/GetPeriodTerms";
    static const String PERIODS_URL = "/api/GetPeriods";
    static const String GETCASHIN_URL = "/api/GetCashinData";
    static const String CURRICULUMS_URL = "/api/GetCurriculums";
    static const String MARKBOOK_URL = "/api/GetMarkbookData";
    static const String MESSAGES_URL = "/api/GetMessages";
    static const String MESSAGE_SET_READ = "/api/SetReadedMessage";
    static const String PETITIONS_COUNT_URL = "/api/RequestForm/GetNumberOfRequestForms";
    static const String PETITIONS_TEMPLATES_URL = "/api/RequestForm/GetStudentRequestFormTemplates";
    static const String PETITIONS_SUBMITTED_URL = "/api/RequestForm/GetSubmittedRequestForms";
    static const String PETITIONS_TEMPLATE_DETAILS_URL = "/api/RequestForm/GetStudentRequestFormTemplateDetails";
    static const String PETITIONS_GET_FORM_URL = "/api/RequestFormCore/GetStudentRequestForm";
    static const String PETITIONS_SAVE_PAGE_URL = "/api/RequestFormCore/SavePageAndStepNext";
    static const String PETITIONS_CURRENT_PAGE_URL = "/api/RequestFormCore/GetCurrentPage";
    static const String PETITIONS_GENERATE_PDF_URL = "/api/RequestFormCore/GenerateRequestFormPdf";
    static const String PETITIONS_SUBMIT_URL = "/api/RequestFormCore/Submit";
    static const String PETITIONS_STARTED_TEMPLATES_URL = "/api/RequestForm/GetStartedRequestFormTemplates";
    static const String PETITIONS_STARTED_DETAILS_URL = "/api/RequestForm/GetStartedRequestFormTemplateDetails";
    static const String PETITIONS_INVALIDATE_URL = "/api/RequestFormCore/Invalidate";
    static const String PERSONAL_DATA_GENERAL_URL = "/api/PersonalData/GetGeneralUserData";
    static const String PERSONAL_DATA_DOCUMENTS_URL = "/api/PersonalData/GetStudentPersonalDocuments";
    static const String PERSONAL_DATA_CARD_DETAILS_URL = "/api/PersonalData/GetStudentCardDetails";
    static const String PERSONAL_DATA_CONTACTS_URL = "/api/PersonalData/GetStudentPersonalDataContacts";
    static const String PERSONAL_DATA_BANK_ACCOUNT_URL = "/api/BankAccount/GetDefaultBankAccountNumber";
    static const String PERSONAL_DATA_GDPR_URL = "/api/PersonalData/GetStudentGdprStatements";
    static const String USER_PROFILE_AVATAR_URL = "/api/General/GetUserAvatar";
    static const String USER_PROFILE_SETTINGS_URL = "/api/UserProfile/GetUserProfileSettings";
    static const String USER_PROFILE_SAVE_SETTINGS_URL = "/api/UserProfile/SaveUserProfileSettings";
    static const String USER_PROFILE_FALLBACK_COLORS_URL = "/api/UserProfile/GetDefaultFallbackProfilePictureColorCodes";
    static const String USER_PROFILE_DEFAULT_AVATARS_URL = "/api/UserProfile/GetDefaultAvatars";
    static const String USER_PROFILE_IS_PASSWORD_MOD_ALLOWED_URL = "/api/UserProfile/IsPasswordModificationAllowed";
    static const String DOCUMENT_STORAGE_DASHBOARD_URL = "/api/DocumentContainer/GetDashboardData";
    static const String DOCUMENT_STORAGE_FOR_STUDENT_URL = "/api/DocumentContainer/GetDocumentsUploadedForStudent";
    static const String DOCUMENT_STORAGE_BY_STUDENT_URL = "/api/DocumentContainer/GetDocumentsUploadedByStudent";
    static const String DOCUMENT_STORAGE_TR_URL = "/api/DocumentContainer/GetTrDocuments";
    static const String DOCUMENT_STORAGE_DOWNLOAD_URL = "/api/DocumentContainer/DownloadDocumentationOrZip";
  }
  
  class _APIRequest{
    // POST-REQUEST for old API and modern login
    static Future<String> postRequest(Uri url, String requestBody,{String? bearerToken}) async{
      HttpOverrides.global = NeptunCerts.getCerts();
  
      final client = http.Client();
      final request = http.Request('POST', url);

      request.headers['Content-Type'] = 'application/json';
      if (bearerToken != null && bearerToken.isNotEmpty) {
        request.headers['Authorization'] = 'Bearer $bearerToken';
      }
      request.body = requestBody;

      var response;
      try{
        response = await client.send(request).then((response) {
          // Read and return the response
          return response.stream.bytesToString();
        });

        if (response != null) {
          String responseString = response.toString().trim();
          if (responseString.startsWith('<!DOCTYPE html') || responseString.startsWith('<html')){
            client.close();
            return '{"ErrorMessage": "Hibás URL vagy a Neptun szervere weboldalt küldött válaszként"}';
          }
        }
      }
      catch(error){
        client.close();
        return '{"ErrorMessage": "Hálózati hiba: $error"}';
      }

      // Close the client when done
      client.close();
  
      return response ?? '{}';
    }

    static Future<http.Response> postRequestRaw(Uri url, String requestBody,{String? bearerToken, String? cookie}) async {
      HttpOverrides.global = NeptunCerts.getCerts();
  
      final client = http.Client();
      final request = http.Request('POST', url);

      request.headers['Content-Type'] = 'application/json';
      if (bearerToken != null && bearerToken.isNotEmpty) {
        request.headers['Authorization'] = 'Bearer $bearerToken';
      }
      if (cookie != null && cookie.isNotEmpty) {
        request.headers['Cookie'] = cookie;
      }
      request.body = requestBody;

      try {
        final streamedResponse = await client.send(request);
        final response = await http.Response.fromStream(streamedResponse);
        client.close();
        return response;
      } catch (e) {
        client.close();
        rethrow;
      }
    }

    static String? _extractSessionIdFromJwt(String jwt) {
      try {
        final parts = jwt.split('.');
        if (parts.length >= 2) {
          String normalized = parts[1];
          while (normalized.length % 4 != 0) {
            normalized += '=';
          }
          final decoded = conv.utf8.decode(conv.base64Url.decode(normalized));
          final map = conv.jsonDecode(decoded);
          if (map is Map && map['SessionId'] != null) {
            return map['SessionId'].toString();
          }
        }
      } catch (_) {}
      return null;
    }

    static void _extractAndSaveCookiesAndTokens(http.Response response, String username) {
      final setCookie = response.headers['set-cookie'];
      if (setCookie == null || setCookie.isEmpty) return;

      // Extract device cookie: devicecookie-<BASE64_NEPTUN_CODE>=<VALUE>
      final deviceCookieRegExp = RegExp(r'devicecookie-[a-zA-Z0-9+/=]+=([^;,\s]+)');
      final deviceCookieMatch = deviceCookieRegExp.firstMatch(setCookie);
      if (deviceCookieMatch != null) {
        final cookieValue = deviceCookieMatch.group(1);
        if (cookieValue != null && cookieValue.isNotEmpty) {
          storage.DataCache.setDeviceCookie(username, cookieValue);
        }
      }

      // Extract refresh token: <GUID_OR_NAME>=<JWT_REFRESH_TOKEN>
      final refreshTokenRegExp = RegExp(r'([0-9a-fA-F-]{36}|[a-zA-Z0-9_\-\.]+)=(eyJ[a-zA-Z0-9\-_\.]+)');
      final refreshTokenMatch = refreshTokenRegExp.firstMatch(setCookie);
      if (refreshTokenMatch != null) {
        final cookieName = refreshTokenMatch.group(1);
        final tokenValue = refreshTokenMatch.group(2);
        if (tokenValue != null && tokenValue.isNotEmpty) {
          storage.DataCache.setRefreshToken(tokenValue);
          if (cookieName != null && cookieName.isNotEmpty && !cookieName.startsWith('devicecookie')) {
            storage.DataCache.setSessionCookieName(cookieName);
          }
        }
      }
    }

    static bool _isRefreshingToken = false;

    static Future<bool> tryTokenRefresh() async {
      try {
        final refreshToken = storage.DataCache.getRefreshToken();
        if (refreshToken == null || refreshToken.isEmpty) {
          return false;
        }

        final baseUrl = storage.DataCache.getInstituteUrl();
        if (baseUrl == null || baseUrl.isEmpty) {
          return false;
        }

        final refreshUrl = Uri.parse("$baseUrl/api/Account/GetNewTokens");
        final accessToken = storage.DataCache.getAccessToken() ?? '';
        final username = storage.DataCache.getUsername();

        List<String> cookieParts = [];
        if (username != null && username.isNotEmpty) {
          final savedCookieVal = await storage.DataCache.getDeviceCookie(username);
          if (savedCookieVal != null && savedCookieVal.isNotEmpty) {
            final b64 = conv.base64.encode(conv.utf8.encode(username.toUpperCase()));
            cookieParts.add('devicecookie-$b64=$savedCookieVal');
          }
        }

        String? sessionCookieName = storage.DataCache.getSessionCookieName();
        if (sessionCookieName == null || sessionCookieName.isEmpty) {
          sessionCookieName = _extractSessionIdFromJwt(refreshToken);
        }
        if (sessionCookieName != null && sessionCookieName.isNotEmpty) {
          cookieParts.add('$sessionCookieName=$refreshToken');
        } else {
          cookieParts.add('refreshToken=$refreshToken');
        }

        final cookieHeader = cookieParts.isNotEmpty ? cookieParts.join('; ') : null;

        final response = await postRequestRaw(
          refreshUrl,
          "{}",
          bearerToken: accessToken.isNotEmpty ? accessToken : refreshToken,
          cookie: cookieHeader,
        );

        if (response.statusCode == 200) {
          final bodyJson = conv.jsonDecode(response.body);
          final String? newAccessToken = bodyJson["accessToken"] ?? bodyJson["data"]?["accessToken"];
          if (newAccessToken != null && newAccessToken.isNotEmpty) {
            await storage.DataCache.setAccessToken(newAccessToken);
            if (username != null && username.isNotEmpty) {
              _extractAndSaveCookiesAndTokens(response, username);
            }
            return true;
          }
        }
      } catch (e) {
        debug.log("Error during token refresh: $e");
      }
      return false;
    }

    static Future<String> getRequest(Uri url, {required String bearerToken, bool isRetry = false}) async {
      HttpOverrides.global = NeptunCerts.getCerts();
      final client = http.Client();
      final request = http.Request('GET', url);
      request.headers['Authorization'] = 'Bearer $bearerToken';
      request.headers['Content-Type'] = 'application/json';

      try {
        final streamedResponse = await client.send(request);
        final response = await http.Response.fromStream(streamedResponse);
        client.close();

        // Ha a token lejárt:
        if ((response.statusCode == 401 || response.body.contains('"statusCode": 401') || response.body.contains('Authorization has been denied')) && !isRetry) {

          // --- ÚJ VERSENYHELYZET GÁTLÓ LOGIKA ---
          if (!_isRefreshingToken) {
            _isRefreshingToken = true; // Bezárjuk a lakatot
            debug.log("Token lejárt! Automatikus újra-bejelentkezés indítása...");

            bool refreshSuccess = false;
            if (storage.DataCache.getIsModernApi()) {
              refreshSuccess = await tryTokenRefresh();
            }

            if (!refreshSuccess) {
              final username = storage.DataCache.getUsername()!;
              final password = storage.DataCache.getPassword()!;
              final baseUrl = storage.DataCache.getInstituteUrl()!;

              await InstitutesRequest.validateLoginCredentialsUrl(baseUrl, username, password);
            }

            _isRefreshingToken = false; // Kinyitjuk a lakatot
          } else {
            // Ha egy másik fül már frissíti a tokent, várunk rá!
            debug.log("Egy másik fül már frissít, várakozás...");
            while (_isRefreshingToken) {
              await Future.delayed(const Duration(milliseconds: 100));
            }
          }
          // ----------------------------------------

          // Mindenki megkapja az új tokent, és újra próbálkozik
          final newToken = await storage.DataCache.getAccessToken();
          return await getRequest(url, bearerToken: newToken!, isRetry: true);
        }

        return response.body;
      } catch (e) {
        client.close();
        return '{"ErrorMessage": "$e"}';
      }
    }

    static Future<String> postRequestWithRetry(Uri url, String requestBody, {bool isRetry = false}) async {
      HttpOverrides.global = NeptunCerts.getCerts();
      final client = http.Client();
      final request = http.Request('POST', url);
      final bearerToken = storage.DataCache.getAccessToken() ?? '';
      if (bearerToken.isNotEmpty) {
        request.headers['Authorization'] = 'Bearer $bearerToken';
      }
      request.headers['Content-Type'] = 'application/json';
      request.headers['Accept'] = 'application/json, text/plain, */*';
      request.body = requestBody;

      try {
        final streamedResponse = await client.send(request);
        final response = await http.Response.fromStream(streamedResponse);
        client.close();

        if ((response.statusCode == 401 || response.body.contains('"statusCode": 401') || response.body.contains('Authorization has been denied')) && !isRetry) {
          if (!_isRefreshingToken) {
            _isRefreshingToken = true;
            bool refreshSuccess = false;
            if (storage.DataCache.getIsModernApi()) {
              refreshSuccess = await tryTokenRefresh();
            }
            if (!refreshSuccess) {
              final username = storage.DataCache.getUsername()!;
              final password = storage.DataCache.getPassword()!;
              final baseUrl = storage.DataCache.getInstituteUrl()!;
              await InstitutesRequest.validateLoginCredentialsUrl(baseUrl, username, password);
            }
            _isRefreshingToken = false;
          } else {
            while (_isRefreshingToken) {
              await Future.delayed(const Duration(milliseconds: 100));
            }
          }
          return await postRequestWithRetry(url, requestBody, isRetry: true);
        }

        return response.body;
      } catch (e) {
        client.close();
        return '{"ErrorMessage": "$e"}';
      }
    }

    static Future<http.Response> postRequestRawWithRetry(Uri url, String requestBody, {bool isRetry = false}) async {
      HttpOverrides.global = NeptunCerts.getCerts();
      final client = http.Client();
      final request = http.Request('POST', url);
      final bearerToken = storage.DataCache.getAccessToken() ?? '';
      if (bearerToken.isNotEmpty) {
        request.headers['Authorization'] = 'Bearer $bearerToken';
      }
      request.headers['Content-Type'] = 'application/json';
      request.body = requestBody;

      try {
        final streamedResponse = await client.send(request);
        final response = await http.Response.fromStream(streamedResponse);
        client.close();

        if ((response.statusCode == 401 || response.body.contains('"statusCode": 401') || response.body.contains('Authorization has been denied')) && !isRetry) {
          if (!_isRefreshingToken) {
            _isRefreshingToken = true;
            bool refreshSuccess = false;
            if (storage.DataCache.getIsModernApi()) {
              refreshSuccess = await tryTokenRefresh();
            }
            if (!refreshSuccess) {
              final username = storage.DataCache.getUsername()!;
              final password = storage.DataCache.getPassword()!;
              final baseUrl = storage.DataCache.getInstituteUrl()!;
              await InstitutesRequest.validateLoginCredentialsUrl(baseUrl, username, password);
            }
            _isRefreshingToken = false;
          } else {
            while (_isRefreshingToken) {
              await Future.delayed(const Duration(milliseconds: 100));
            }
          }
          return await postRequestRawWithRetry(url, requestBody, isRetry: true);
        }

        return response;
      } catch (e) {
        client.close();
        rethrow;
      }
    }

    static String getGenericPostData(String username, String password){
      return
        '{'
          '"UserLogin":"$username",'
          '"Password":"$password"'
        '}';
    }
  }

  class TermsRequest{
    static List<Term> sortTerms(List<Term> termList) {
      termList.sort((a, b) {
        final reg = RegExp(r'(\d{4})/(?:\d{2}|\d{4})/(\d)');
        final matchA = reg.firstMatch(a.termName);
        final matchB = reg.firstMatch(b.termName);
        if (matchA != null && matchB != null) {
          int yearA = int.tryParse(matchA.group(1) ?? '0') ?? 0;
          int semA = int.tryParse(matchA.group(2) ?? '0') ?? 0;
          int yearB = int.tryParse(matchB.group(1) ?? '0') ?? 0;
          int semB = int.tryParse(matchB.group(2) ?? '0') ?? 0;
          if (yearA != yearB) return yearA.compareTo(yearB);
          return semA.compareTo(semB);
        }
        return a.termName.compareTo(b.termName);
      });
      return termList;
    }

    static Future<List<Term>> getTerms({bool forceRefresh = false}) async {
      if (storage.DataCache.getIsDemoAccount() ?? false) {
        return [Term('70876', 'DEMO Félév (2025/26/1)'), Term('70877', 'DEMO Félév (2025/26/2)')];
      }
      if (!forceRefresh) {
        final cachedRaw = storage.DataCache.getCachedTermsRaw();
        if (cachedRaw.isNotEmpty) {
          try {
            final list = cachedRaw.map((s) => Term.deserialize(s)).toList();
            if (list.isNotEmpty) {
              return sortTerms(list);
            }
          } catch (_) {}
        }
      }

      List<Term> terms = [];
      if (storage.DataCache.getIsModernApi()) {
        try {
          final token = await storage.DataCache.getAccessToken();
          String baseUrl = storage.DataCache.getInstituteUrl() ?? '';
          
          // 1. Try RegisteredCourses/GetTerms
          try {
            final rTermsUrl = Uri.parse("$baseUrl/api/RegisteredCourses/GetTerms");
            final rTermsResponse = await _APIRequest.getRequest(rTermsUrl, bearerToken: token!);
            final rTermsDecoded = conv.json.decode(rTermsResponse);
            if (rTermsDecoded['data'] != null && rTermsDecoded['data'] is List) {
              for (var item in rTermsDecoded['data']) {
                final val = item['value']?.toString() ?? '';
                final text = item['text']?.toString() ?? item['termName']?.toString() ?? val;
                if (val.isNotEmpty) {
                  terms.add(Term(val, text));
                }
              }
            }
          } catch (_) {}

          // 2. Try TakenSubjects/Terms
          if (terms.isEmpty) {
            try {
              final termsUrl = Uri.parse("$baseUrl/api/TakenSubjects/Terms");
              final termsResponse = await _APIRequest.getRequest(termsUrl, bearerToken: token!);
              final termsDecoded = conv.json.decode(termsResponse);
              if (termsDecoded['data'] != null && termsDecoded['data'] is List) {
                for (var item in termsDecoded['data']) {
                  final val = item['value']?.toString() ?? '';
                  final text = item['text']?.toString() ?? item['termName']?.toString() ?? val;
                  if (val.isNotEmpty) {
                    terms.add(Term(val, text));
                  }
                }
              }
            } catch (_) {}
          }

          // 3. Try Periods/GetTerms
          if (terms.isEmpty) {
            try {
              final pTermsUrl = Uri.parse("$baseUrl/api/Periods/GetTerms");
              final pTermsResponse = await _APIRequest.getRequest(pTermsUrl, bearerToken: token!);
              final pTermsDecoded = conv.json.decode(pTermsResponse);
              if (pTermsDecoded['data'] != null && pTermsDecoded['data'] is List) {
                for (var item in pTermsDecoded['data']) {
                  final val = item['value']?.toString() ?? '';
                  final text = item['text']?.toString() ?? item['termName']?.toString() ?? val;
                  if (val.isNotEmpty) {
                    terms.add(Term(val, text));
                  }
                }
              }
            } catch (_) {}
          }
        } catch (e) {
          debug.log("Hiba a modern félévek lekérésekor: $e");
        }
      } else {
        try {
          final username = storage.DataCache.getUsername();
          final password = storage.DataCache.getPassword();
          final url = Uri.parse(storage.DataCache.getInstituteUrl()! + URLs.PERIODTERMS_URL);
          final request = await _APIRequest.postRequest(url, _APIRequest.getGenericPostData(username!, password!));

          final decoded = conv.json.decode(request);
          if (decoded['PeriodTermsList'] != null && decoded['PeriodTermsList'] is List) {
            List<dynamic> termList = decoded['PeriodTermsList'];
            for (var term in termList){
              final map = term as Map<String, dynamic>;
              terms.add(Term(map['Id'], map['TermName'] ?? ''));
            }
          }
        } catch (e) {
          debug.log("Hiba a régi félévek lekérésekor: $e");
        }
      }

      if (terms.isNotEmpty) {
        terms = sortTerms(terms);
        await storage.DataCache.setCachedTermsRaw(terms.map((t) => t.serialize()).toList());
        final currentSelected = storage.DataCache.getSelectedTermId();
        final currentSelectedName = storage.DataCache.getSelectedTermName();

        Term? matchedTerm;
        if (currentSelected != null && terms.any((t) => t.id == currentSelected)) {
          matchedTerm = terms.firstWhere((t) => t.id == currentSelected);
        } else if (currentSelectedName != null && terms.any((t) => t.termName == currentSelectedName)) {
          matchedTerm = terms.firstWhere((t) => t.termName == currentSelectedName);
        } else {
          matchedTerm = terms.last;
        }

        await storage.DataCache.setSelectedTermId(matchedTerm.id);
        await storage.DataCache.setSelectedTermName(matchedTerm.termName);
      }
      return terms;
    }
  }
  
  class InstitutesRequest{
    static Future<List<dynamic>?> fetchInstitudesJSON() async{
      //return _APIRequest.postRequest(Uri.parse(URLs.INSTITUTIONS_URL), '{}');
      var json;
      try{
        json = await getRawJsonWithNameUrlPairs();
      }
      catch(error){
      }
      return json;
    }

    static Future<List<dynamic>?> getRawJsonWithNameUrlPairs() async{
      final url = Uri.parse('https://raw.githubusercontent.com/zoligamer/Neptun-Mobile-fork/refs/heads/main/universityNameUrlPairs.json');
      final response = await http.get(url);

      if (response.statusCode != 200) {
        return null;
      }

      Map<String, dynamic> jsonMap = conv.json.decode(response.body);
      return jsonMap["Institutes"];
    }
  
    static List<Institute> getDataFromInstitudesJSON(List<dynamic> jsonMap){
      var newList = <Institute>[].toList();
      for (var item in jsonMap){
        var item2 = item as Map<String, dynamic>;
        String name = item2['Name'];
        String url = item2['Url'] ?? "NULL";
        if(url != "NULL" && name != "DEMO") { //remove obsolete or non existent entries
          newList.add(Institute(name, url));
        }
      }
      return newList;
    }
    static Future<int> validateLoginCredentials(Institute institute, String username, String password) async{
      return validateLoginCredentialsUrl(institute.URL, username, password);
    }
    //
// --- 2FA
    static Future<int> validateLoginCredentialsUrl(String rawUrl, String username, String password) async {
      if(username == 'DEMO' && password == 'DEMO'){
        await storage.DataCache.setIsDemoAccount(1);
        return 1;
      }

      String url = rawUrl.trim();
      if (url.endsWith('/')) url = url.substring(0, url.length - 1);
      bool containsAspx = url.toLowerCase().contains('.aspx');

      String baseUrl = url.replaceAll(RegExp(r'/login(\.aspx)?$', caseSensitive: false), '');
      baseUrl = baseUrl.replaceAll(RegExp(r'/MobileService\.svc$', caseSensitive: false), '');

      // Path normalization for specific institutions is handled by the modern API detection below.

      if (containsAspx) {
        // Try old login first, but fallback to modern login if old login fails (e.g. universities like Semmelweis that use .aspx URLs but require modern API / 2FA)
        bool oldSuccess = await _tryOldLogin(baseUrl, username, password);
        if (oldSuccess) {
          return 1;
        }
        return await _tryModernLogin(baseUrl, username, password);
      } else {
        // Try modern login first, but fallback to old login if modern login fails
        int modernResult = await _tryModernLogin(baseUrl, username, password);
        if (modernResult != 0) {
          return modernResult;
        }
        bool oldSuccess = await _tryOldLogin(baseUrl, username, password);
        return oldSuccess ? 1 : 0;
      }
    }

    static Future<int> _tryModernLogin(String baseUrl, String username, String password) async {
      final modernApiUrl = Uri.parse("$baseUrl/api/Account/Authenticate");
      final body = conv.jsonEncode({
        "userName": username, "password": password,
        "captcha": "", "captchaIdentifier": "", "token": "", "LCID": 1038
      });

      // 1. Try with saved device cookie if exists
      final savedCookieVal = await storage.DataCache.getDeviceCookie(username);
      if (savedCookieVal != null && savedCookieVal.isNotEmpty) {
        try {
          final b64 = conv.base64.encode(conv.utf8.encode(username.toUpperCase()));
          final cookieHeader = 'devicecookie-$b64=$savedCookieVal';
          final responseRaw = await _APIRequest.postRequestRaw(modernApiUrl, body, cookie: cookieHeader);

          if (responseRaw.statusCode == 200 || responseRaw.statusCode == 202) {
            final response = conv.jsonDecode(responseRaw.body);
            _APIRequest._extractAndSaveCookiesAndTokens(responseRaw, username);

            final is2fa = response["data"] != null && (response["data"]["isTwoFactorRequired"] == true || response["data"]["requiresTwoFactor"] == true);
            if (is2fa) {
              await storage.DataCache.setInstituteUrl(baseUrl);
              await storage.DataCache.setAccessToken(response["data"]["twoFactorLoginToken"]);
              return 2; // 2FA required
            }

            if (response["data"] != null && response["data"]["accessToken"] != null) {
              await storage.DataCache.setAccessToken(response["data"]["accessToken"]);
              await storage.DataCache.setIsModernApi(true);
              await storage.DataCache.setInstituteUrl(baseUrl);
              return 1; // Success
            }
          }
        } catch (_) { }
        // If cookie-based login failed or was rejected, clear the stale cookie and fallback to clean login
        await storage.DataCache.setDeviceCookie(username, null);
      }

      // 2. Clean login attempt without cookies (first-time login or cookie invalidation)
      try {
        final responseRaw = await _APIRequest.postRequestRaw(modernApiUrl, body);
        final response = conv.jsonDecode(responseRaw.body);

        _APIRequest._extractAndSaveCookiesAndTokens(responseRaw, username);

        final is2fa = response["data"] != null && (response["data"]["isTwoFactorRequired"] == true || response["data"]["requiresTwoFactor"] == true);
        if (is2fa) {
          await storage.DataCache.setInstituteUrl(baseUrl);
          await storage.DataCache.setAccessToken(response["data"]["twoFactorLoginToken"]);
          return 2; // 2FA required
        }

        if (response["data"] != null && response["data"]["accessToken"] != null) {
          await storage.DataCache.setAccessToken(response["data"]["accessToken"]);
          await storage.DataCache.setIsModernApi(true);
          await storage.DataCache.setInstituteUrl(baseUrl);
          return 1; // Success
        }
      } catch (e) { }

      return 0; // Failure
    }


    static Future<bool> submitTwoFactorCode(String username, String password, String code) async {
      try {
        String baseUrl = storage.DataCache.getInstituteUrl() ?? '';

        final url = Uri.parse("$baseUrl/api/Account/Authenticate");
        final body = conv.jsonEncode({
          "userName": username,
          "password": password,
          "captcha":"",
          "captchaIdentifier":"",
          "token": code,
          "LCID":1038
        });

        // Load device cookie if exists
        final savedCookieVal = await storage.DataCache.getDeviceCookie(username);
        String? cookieHeader;
        if (savedCookieVal != null && savedCookieVal.isNotEmpty) {
          final b64 = conv.base64.encode(conv.utf8.encode(username.toUpperCase()));
          cookieHeader = 'devicecookie-$b64=$savedCookieVal';
        }

        final responseRaw = await _APIRequest.postRequestRaw(url, body, cookie: cookieHeader);
        final response = conv.jsonDecode(responseRaw.body);

        // Extract and save cookies/tokens
        _APIRequest._extractAndSaveCookiesAndTokens(responseRaw, username);

        if (response["data"] != null && response["data"]["accessToken"] != null) {
          await storage.DataCache.setAccessToken(response["data"]["accessToken"]);
          await storage.DataCache.setIsModernApi(true);
          await storage.DataCache.setInstituteUrl(baseUrl);
          return true;
        }
      } catch (e) { }
      return false;
    }
    static Future<bool> _tryOldLogin(String baseUrl, String username, String password) async {
      try {
        final oldApiUrl = Uri.parse("$baseUrl/MobileService.svc" + URLs.TRAININGS_URL);
        final request = await _APIRequest.postRequest(
            oldApiUrl,
            _APIRequest.getGenericPostData(username, password)
        );

        if (request.trim().startsWith('{')) {
          final decodedResponse = conv.json.decode(request);
          if (decodedResponse["ErrorMessage"] == null) {
            await storage.DataCache.setIsModernApi(false);
            await storage.DataCache.setInstituteUrl("$baseUrl/MobileService.svc");
            return true;
          }
        }
      } catch (e) { }
      return false;
    }

    static Future<int?> getFirstStudyweek({String? termId}) async{
      final periods = await PeriodsRequest.getPeriods(termId: termId);
      if(storage.DataCache.getIsDemoAccount()!){
        return DateTime(2024, 9, 1).millisecondsSinceEpoch;
      }
      final now = DateTime.now().millisecondsSinceEpoch;
      if(periods == null || periods.isEmpty){
        return null;
      }
  
      PeriodEntry? period;
      int neededExtraWeeks = 0;
      for (var item in periods){
        final name = item.name.toLowerCase();
        if(name.contains('végleges tárgyjelentkezés') || name.contains('szorgalmi időszak') || name.contains('oktatási időszak')){
          if(item.startEpoch <= now || period == null || (item.startEpoch <= now && item.startEpoch > period.startEpoch)){
            period = item;
            neededExtraWeeks = 0;
          }
        }
      }
      if(period == null){
        for (var item in periods){
          final name = item.name.toLowerCase();
          if(name.contains('bejelentkezési időszak') || name.contains('regisztrációs időszak')){
            if(item.startEpoch <= now || period == null || (item.startEpoch <= now && item.startEpoch > period.startEpoch)){
              period = item;
              neededExtraWeeks = 1;
            }
          }
        }
        if(period == null){
          period = periods.first;
        }
      }
  
      final date = DateTime.fromMillisecondsSinceEpoch(period.startEpoch);
      int difference = date.weekday - DateTime.monday;
      final roundedDate = DateTime(date.year, date.month, date.day).subtract(Duration(days: difference)).add(Duration(days: 7 * neededExtraWeeks));

      return roundedDate.millisecondsSinceEpoch;
    }
  }

class CalendarRequest {
  static List<String>? _cachedTrainingIds;

  static Future<List<String>> getStudentTrainingIds({bool forceRefresh = false}) async {
    if (forceRefresh) {
      _cachedTrainingIds = null;
    }
    if (_cachedTrainingIds != null && _cachedTrainingIds!.isNotEmpty) return _cachedTrainingIds!;
    if (!(storage.DataCache.getIsModernApi())) return [];

    final storedId = storage.DataCache.getStudentTrainingId();
    if (!forceRefresh && storedId != null && storedId.isNotEmpty) {
      _cachedTrainingIds = [storedId];
      return _cachedTrainingIds!;
    }

    try {
      final token = await storage.DataCache.getAccessToken();
      if (token == null || token.isEmpty) return [];
      String baseUrl = storage.DataCache.getInstituteUrl() ?? '';

      // Tier 1: /api/Calendar/GetStudentTrainings
      try {
        final url = Uri.parse("$baseUrl/api/Calendar/GetStudentTrainings");
        final responseRaw = await _APIRequest.getRequest(url, bearerToken: token);
        final decoded = conv.json.decode(responseRaw);

        List<String> ids = [];
        if (decoded['data'] != null && decoded['data'] is List) {
          for (var training in decoded['data']) {
            final tid = training['studentTrainingId']?.toString();
            if (tid != null && tid.isNotEmpty && !ids.contains(tid)) {
              if (training['actualStudentTraining'] == true) {
                ids.insert(0, tid);
              } else {
                ids.add(tid);
              }
            }
          }
        }
        if (ids.isNotEmpty) {
          _cachedTrainingIds = ids;
          await storage.DataCache.setStudentTrainingId(ids.first);
          return ids;
        }
      } catch (e) {
        debug.log("Hiba a GetStudentTrainings lekérésekor: $e");
      }

      // Tier 2: /api/UserInfo
      try {
        final uInfoUrl = Uri.parse("$baseUrl/api/UserInfo");
        final uInfoRaw = await _APIRequest.getRequest(uInfoUrl, bearerToken: token);
        final uInfoDecoded = conv.json.decode(uInfoRaw);
        if (uInfoDecoded['data'] != null) {
          final tid = uInfoDecoded['data']['studentTrainingId']?.toString();
          if (tid != null && tid.isNotEmpty) {
            _cachedTrainingIds = [tid];
            await storage.DataCache.setStudentTrainingId(tid);
            return [tid];
          }
        }
      } catch (e) {
        debug.log("Hiba a UserInfo lekérésekor: $e");
      }

      // Tier 3: /api/ContextUserProfile/MyTrainings
      try {
        final myTrainingsUrl = Uri.parse("$baseUrl/api/ContextUserProfile/MyTrainings");
        final myTrainingsRaw = await _APIRequest.getRequest(myTrainingsUrl, bearerToken: token);
        final myTrainingsDecoded = conv.json.decode(myTrainingsRaw);
        List<String> ids = [];
        if (myTrainingsDecoded['data'] != null && myTrainingsDecoded['data'] is List) {
          for (var training in myTrainingsDecoded['data']) {
            final tid = training['studentTrainingId']?.toString();
            if (tid != null && tid.isNotEmpty && !ids.contains(tid)) {
              ids.add(tid);
            }
          }
        }
        if (ids.isNotEmpty) {
          _cachedTrainingIds = ids;
          await storage.DataCache.setStudentTrainingId(ids.first);
          return ids;
        }
      } catch (e) {
        debug.log("Hiba a MyTrainings lekérésekor: $e");
      }

    } catch (e) {
      debug.log("Hiba a student trainings lekérésekor: $e");
    }

    if (storedId != null && storedId.isNotEmpty) {
      return [storedId];
    }
    return [];
  }

  static Future<String?> getStudentTrainingId({bool forceRefresh = false}) async {
    final ids = await getStudentTrainingIds(forceRefresh: forceRefresh);
    return ids.isNotEmpty ? ids.first : null;
  }

  static List<CalendarEntry> getCalendarEntriesFromJSON(String jsonString) {
    if (jsonString == '{}' || jsonString.isEmpty) return [];
    try {
      final decoded = conv.json.decode(jsonString);
      List<CalendarEntry> list = [];
      if (storage.DataCache.getIsModernApi()) {
        if (decoded is Map && decoded['calendarData'] != null && decoded['calendarData'] is List) {
          for (var item in decoded['calendarData']) {
            if (item is! Map) continue;
            int startMs = item['start_ms'] is int ? item['start_ms'] : int.tryParse(item['start_ms']?.toString() ?? '0') ?? 0;
            int endMs = item['end_ms'] is int ? item['end_ms'] : int.tryParse(item['end_ms']?.toString() ?? '0') ?? 0;
            int eventType = item['type'] is int ? item['type'] : int.tryParse(item['type']?.toString() ?? '0') ?? 0;

            list.add(CalendarEntry.fromModern(
              startEpoch: startMs,
              endEpoch: endMs,
              location: item['location']?.toString() ?? "Nincs megadva",
              title: item['title']?.toString() ?? "Nincs cím",
              eventType: eventType,
              subjectCode: item['subjectCode']?.toString() ?? '-',
              courseType: item['courseType']?.toString(),
              teacher: item['teacher']?.toString() ?? 'Nincs megadva',
              classInstanceId: item['classInstanceId']?.toString(),
              taskId: item['taskId']?.toString(),
            ));
          }
        }
        return list;
      }

      if (decoded['calendarData'] != null && decoded['calendarData'] is List) {
        for (var item in decoded['calendarData']) {
          String rawStart = item['start']?.toString().replaceAll(RegExp(r'[^0-9]'), '') ?? '';
          String rawEnd = item['end']?.toString().replaceAll(RegExp(r'[^0-9]'), '') ?? '';

          list.add(CalendarEntry(
            rawStart.isEmpty ? '0' : rawStart,
            rawEnd.isEmpty ? '0' : rawEnd,
            item['location'] ?? "Nincs megadva",
            item['title'] ?? "Nincs cím",
            item['type'] == 1,
          ));
        }
      }
      return list;
    } catch (e) {
      debug.log("Hiba a naptár JSON feldolgozásakor: $e");
      return [];
    }
  }

  static Future<String> makeCalendarRequest(String calendarJson) async {
    if (storage.DataCache.getIsDemoAccount()! || storage.DataCache.getHasICSFile()!) {
      return '{}';
    }

    if (storage.DataCache.getIsModernApi()) {
      try {
        final oldPayload = conv.json.decode(calendarJson);
        final startDateRaw = (oldPayload['startDate'] ?? oldPayload['StartDate']).toString();

        final numRegex = RegExp(r'\d+');
        final startEpoch = int.parse(numRegex.firstMatch(startDateRaw)!.group(0)!);

        final startDate = DateTime.fromMillisecondsSinceEpoch(startEpoch);
        final sunday = startDate.add(const Duration(days: 6));

        final startIso = "${startDate.year.toString().padLeft(4, '0')}-${startDate.month.toString().padLeft(2, '0')}-${startDate.day.toString().padLeft(2, '0')}T00:00:00.000";
        final endIso = "${sunday.year.toString().padLeft(4, '0')}-${sunday.month.toString().padLeft(2, '0')}-${sunday.day.toString().padLeft(2, '0')}T23:59:59.999";

        String baseUrl = storage.DataCache.getInstituteUrl() ?? '';
        String responseRaw = "";
        bool needsReAuth = false;

        bool dispClasses = storage.DataCache.getDisplayClasses() ?? true;
        bool dispExams = storage.DataCache.getDisplayExams() ?? true;
        bool dispPeriods = storage.DataCache.getDisplayPeriods() ?? true;

        List<String> trainingIds = await getStudentTrainingIds(forceRefresh: false);
        final token = await storage.DataCache.getAccessToken();

        if (token != null && token.isNotEmpty) {
          final baseUri = Uri.parse(baseUrl);
          final cleanBasePath = baseUri.path.endsWith('/') ? baseUri.path.substring(0, baseUri.path.length - 1) : baseUri.path;
          final calendarPath = '$cleanBasePath/api/Calendar/GetCalendarEvents'.replaceAll('//', '/');

          Map<String, String> queryParams = {
            'startDate': startIso,
            'endDate': endIso,
            'isClassesVisible': dispClasses.toString(),
            'isExamsVisible': dispExams.toString(),
            'isFinalExamsVisible': 'true',
            'isOnlineMeetingsVisible': 'true',
            'isOtherEventsVisible': 'true',
            'isPeriodsVisible': dispPeriods.toString(),
            'isTasksVisible': 'true',
          };
          for (int i = 0; i < trainingIds.length; i++) {
            queryParams['studentTrainingIds[$i]'] = trainingIds[i];
          }

          final url = baseUri.replace(path: calendarPath, queryParameters: queryParams);
          debug.log("Naptár kérés küldése: $url");

          responseRaw = await _APIRequest.getRequest(url, bearerToken: token);

          if (responseRaw.contains('"statusCode":410') || 
              responseRaw.contains('Authorization has been denied') || 
              responseRaw.contains('"statusCode": 401') || 
              responseRaw.contains('"statusCode":401') ||
              responseRaw.contains('A megadott kérelem nem engedélyezett') ||
              responseRaw.contains('Unauthorized')) {
            needsReAuth = true;
          }
        } else {
          needsReAuth = true;
        }

        if (needsReAuth) {
          debug.log("Naptár: Lejárt token/ID érzékelve. Újra-azonosítás indul...");
          final username = storage.DataCache.getUsername()!;
          final password = storage.DataCache.getPassword()!;
          await InstitutesRequest.validateLoginCredentialsUrl(baseUrl, username, password);

          final newTrainingIds = await getStudentTrainingIds(forceRefresh: true);
          final newToken = await storage.DataCache.getAccessToken();

          if (newToken != null && newToken.isNotEmpty) {
            final baseUri = Uri.parse(baseUrl);
            final cleanBasePath = baseUri.path.endsWith('/') ? baseUri.path.substring(0, baseUri.path.length - 1) : baseUri.path;
            final calendarPath = '$cleanBasePath/api/Calendar/GetCalendarEvents'.replaceAll('//', '/');

            Map<String, String> queryParams = {
              'startDate': startIso,
              'endDate': endIso,
              'isClassesVisible': dispClasses.toString(),
              'isExamsVisible': dispExams.toString(),
              'isFinalExamsVisible': 'true',
              'isOnlineMeetingsVisible': 'true',
              'isOtherEventsVisible': 'true',
              'isPeriodsVisible': dispPeriods.toString(),
              'isTasksVisible': 'true',
            };
            for (int i = 0; i < newTrainingIds.length; i++) {
              queryParams['studentTrainingIds[$i]'] = newTrainingIds[i];
            }

            final retryUrl = baseUri.replace(path: calendarPath, queryParameters: queryParams);
            responseRaw = await _APIRequest.getRequest(retryUrl, bearerToken: newToken);
          }
        }

        // Fallback ha studentTrainingIds-szel 400-at vagy üreset adna vissza
        if ((responseRaw.contains('400') || responseRaw.isEmpty || responseRaw == '{"data":[]}' || responseRaw == '{"data":null}') && token != null) {
          final baseUri = Uri.parse(baseUrl);
          final cleanBasePath = baseUri.path.endsWith('/') ? baseUri.path.substring(0, baseUri.path.length - 1) : baseUri.path;
          final calendarPath = '$cleanBasePath/api/Calendar/GetCalendarEvents'.replaceAll('//', '/');

          Map<String, String> fallbackParams = {
            'startDate': startIso,
            'endDate': endIso,
            'isClassesVisible': dispClasses.toString(),
            'isExamsVisible': dispExams.toString(),
            'isFinalExamsVisible': 'true',
            'isOnlineMeetingsVisible': 'true',
            'isOtherEventsVisible': 'true',
            'isPeriodsVisible': dispPeriods.toString(),
            'isTasksVisible': 'true',
          };
          final fallbackUrl = baseUri.replace(path: calendarPath, queryParameters: fallbackParams);
          final fbRaw = await _APIRequest.getRequest(fallbackUrl, bearerToken: token);
          if (fbRaw.isNotEmpty && !fbRaw.contains('400') && !fbRaw.contains('Error')) {
            responseRaw = fbRaw;
          }
        }

        final newApiData = conv.json.decode(responseRaw);
        List<Map<String, dynamic>> mappedList = [];
        final Set<String> seenEventKeys = {};

        if (newApiData is Map && newApiData['data'] != null) {
          var dataPart = newApiData['data'];
          Iterable items = dataPart is List ? dataPart : [dataPart];

          for (var event in items) {
            if (event is! Map) continue;
            final typeId = event['eventTypeId'] ?? 0;
            if (typeId == 6) {
              continue; // Szemeszter időszak banner kihagyása a heti nézetben
            }

            final startStr = event['startDate']?.toString();
            final endStr = event['endDate']?.toString();
            if (startStr == null || endStr == null) continue;

            final eventStartEpoch = DateTime.tryParse(startStr)?.millisecondsSinceEpoch ?? 0;
            final eventEndEpoch = DateTime.tryParse(endStr)?.millisecondsSinceEpoch ?? 0;

            final title = event['name'] ?? event['subjectName'] ?? event['title'] ?? 'Ismeretlen';
            final classInstanceId = event['classInstanceId']?.toString() ?? '';
            final taskId = event['id']?.toString() ?? event['taskId']?.toString() ?? event['midTermTaskId']?.toString() ?? '';

            final dedupeKey = "${classInstanceId}_${taskId}_${eventStartEpoch}_${eventEndEpoch}_$title";
            if (!seenEventKeys.add(dedupeKey)) {
              continue; // Duplikált esemény kihagyása
            }

            final subjectCode = event['courseCode'] ?? event['subjectCode'] ?? '-';
            final courseType = event['courseTypeName'] ?? event['courseType'] ?? event['typeName'] ?? event['type'] ?? '';

            mappedList.add({
              'start_ms': eventStartEpoch,
              'end_ms': eventEndEpoch,
              'location': event['rooms'] ?? event['room'] ?? event['location'] ?? 'Nincs megadva',
              'title': title,
              'type': typeId,
              'subjectCode': subjectCode,
              'courseType': courseType.toString(),
              'teacher': event['courseTutor'] ?? event['teacher'] ?? 'Nincs megadva',
              'classInstanceId': classInstanceId,
              'taskId': taskId,
            });
          }
        }
        return conv.jsonEncode({"calendarData": mappedList});

      } catch (e) {
        debug.log("Naptár lekérési hiba: $e");
        return '{"calendarData": []}';
      }
    } else {
      final url = Uri.parse(storage.DataCache.getInstituteUrl()! + URLs.CALENDAR_URL);
      final request = await _APIRequest.postRequest(url, calendarJson);
      return request;
    }
  }


  static Future<Map<String, String>> getCourseDetails(String classInstanceId) async {
    if (storage.DataCache.getIsModernApi() != true) {
      return {"room": "Nem támogatott (Régi API)", "teacher": "Nem támogatott", "type": "", "code": ""};
    }

    final cachedRoom = await storage.getString('room_$classInstanceId');
    final cachedTeacher = await storage.getString('teacher_$classInstanceId');
    final cachedType = await storage.getString('type_$classInstanceId');
    final cachedCode = await storage.getString('code_$classInstanceId');

    if (!(storage.DataCache.getHasNetwork())) {
      if (cachedRoom != null) {
        return {
          "room": cachedRoom,
          "teacher": cachedTeacher ?? "Nincs tanár",
          "type": cachedType ?? "",
          "code": cachedCode ?? "",
        };
      }
      return {"room": "Nincs internet", "teacher": "Offline mód", "type": "", "code": ""};
    }

    try {
      final token = await storage.DataCache.getAccessToken();
      String baseUrl = storage.DataCache.getInstituteUrl() ?? '';

      final url = Uri.parse("$baseUrl/api/Calendar/GetCourseDetails?classInstanceId=$classInstanceId&webexMeetingId=null");
      final responseRaw = await _APIRequest.getRequest(url, bearerToken: token!);
      final decoded = conv.json.decode(responseRaw);

      if (decoded['data'] != null) {
        final d = decoded['data'];
        final r = d['room']?.toString() ?? d['rooms']?.toString() ?? "Nincs terem";
        final t = d['courseTutor']?.toString() ?? d['tutor']?.toString() ?? d['teacher']?.toString() ?? "Nincs tanár";
        final type = d['courseTypeName']?.toString() ?? d['courseType']?.toString() ?? d['typeName']?.toString() ?? d['type']?.toString() ?? "";
        final code = d['subjectCode']?.toString() ?? d['courseCode']?.toString() ?? "";

        await storage.saveString('room_$classInstanceId', r);
        await storage.saveString('teacher_$classInstanceId', t);
        if (type.isNotEmpty) await storage.saveString('type_$classInstanceId', type);
        if (code.isNotEmpty) await storage.saveString('code_$classInstanceId', code);

        return {"room": r, "teacher": t, "type": type, "code": code};
      }
    } catch (e) {
      debug.log("Hiba az óra részleteinek lekérésekor: $e");
    }

    if (cachedRoom != null) {
      return {
        "room": cachedRoom,
        "teacher": cachedTeacher ?? "Nincs tanár",
        "type": cachedType ?? "",
        "code": cachedCode ?? "",
      };
    }

    return {"room": "Hiba a betöltésnél", "teacher": "Hiba a betöltésnél", "type": "", "code": ""};
  }


  //missing details definition. pulls class location and uh... idk just fills the class
  static Future<void> fillMissingDetails(List<CalendarEntry> entries, Function onUpdate) async {
    bool hasNetwork = storage.DataCache.getHasNetwork();
    String? token;
    String baseUrl = '';

    if (hasNetwork) {
      token = await storage.DataCache.getAccessToken();
      baseUrl = storage.DataCache.getInstituteUrl() ?? '';
    }

    bool didUpdateUI = false;
    // Régi: for (var entry in entries) {
    for (var entry in entries.toList()) {
      if (entry.isTask && entry.taskId != null && entry.taskId!.isNotEmpty) {
        final cachedSubject = await storage.getString('task_sub_${entry.taskId}');


        if (cachedSubject != null && cachedSubject.isNotEmpty) {
          if (entry.location != cachedSubject) {
            entry.location = cachedSubject;
            didUpdateUI = true;
          }
          continue;
        }

        if (hasNetwork && token != null) {
          try {
            final url = Uri.parse("$baseUrl/api/Tasks/GetTaskDetail?midtermTaskId=${entry.taskId}");
            final responseRaw = await _APIRequest.getRequest(url, bearerToken: token);
            final decoded = conv.json.decode(responseRaw);

            if (decoded['data'] != null) {
              final subject = decoded['data']['subjectName'] ?? "Ismeretlen tárgy";
              final type = decoded['data']['midtermTaskType'] ?? "Feladat";
              final result = decoded['data']['midtermResult'] ?? "Nincs eredmény";

              entry.location = subject;
              didUpdateUI = true;


              await storage.saveString('task_sub_${entry.taskId}', subject);
              await storage.saveString('task_type_${entry.taskId}', type);
              await storage.saveString('task_res_${entry.taskId}', result);

              onUpdate();
            }
          } catch(e) {}
          await Future.delayed(const Duration(milliseconds: 75));
        }
        continue;
      }
      if (entry.classInstanceId == null || entry.classInstanceId!.isEmpty) continue;

      final cachedRoom = await storage.getString('room_${entry.classInstanceId}');
      final cachedTeacher = await storage.getString('teacher_${entry.classInstanceId}');

      if (cachedRoom != null && cachedRoom.isNotEmpty && cachedRoom != "Nincs terem") {
        if (entry.location != cachedRoom || entry.teacher != cachedTeacher) {
          entry.location = cachedRoom;
          entry.teacher = cachedTeacher ?? "Nincs tanár";
          didUpdateUI = true;
        }
        continue;
      }

      if (hasNetwork && token != null) {
        try {
          final url = Uri.parse("$baseUrl/api/Calendar/GetCourseDetails?classInstanceId=${entry.classInstanceId}&webexMeetingId=null");
          final responseRaw = await _APIRequest.getRequest(url, bearerToken: token);
          final decoded = conv.json.decode(responseRaw);

          if (decoded['data'] != null) {
            final r = decoded['data']['room'];
            final finalRoom = (r == null || r.toString().trim().isEmpty) ? "Nincs terem" : r.toString();
            final t = decoded['data']['courseTutor'] ?? "Nincs tanár";

            entry.location = finalRoom;
            entry.teacher = t;
            didUpdateUI = true;

            await storage.saveString('room_${entry.classInstanceId}', finalRoom);
            await storage.saveString('teacher_${entry.classInstanceId}', t);

            onUpdate();
          }
        } catch(e) {}

        await Future.delayed(const Duration(milliseconds: 300));
      }
    }

    if (didUpdateUI) {
      onUpdate();
    }
  }

    static String getCalendarOneWeekJSON(String username, String password, int weekOffset, {String? termId}){
      if(storage.DataCache.getIsDemoAccount()!){
        return '';
      }
      final DateTime now = DateTime.now();
      final mondayThisWeek = DateTime(now.year, now.month, now.day).subtract(Duration(days: now.weekday - 1));
      final int deltaWeeks = weekOffset - 1;

      final targetMonday = mondayThisWeek.add(Duration(days: deltaWeeks * 7));
      final targetSunday = targetMonday.add(const Duration(days: 6, hours: 23, minutes: 59, seconds: 59, milliseconds: 999));

      final epochStart = targetMonday.millisecondsSinceEpoch;
      final epochEnd = targetSunday.millisecondsSinceEpoch;

      final activeTermId = termId ?? storage.DataCache.getSelectedTermId();
      final termInt = int.tryParse(activeTermId ?? '0') ?? 0;

      return
        '{'
          '"UserLogin":"$username",'
          '"Password":"$password",'
          '"Time":true,'
          '"Exam":true,'
          '"startDate":"/Date($epochStart)/",'
          '"endDate":"/Date($epochEnd)/",'
          '"TotalRowCount":-1,'
          '"filter":{"TermID":$termInt}'
        '}';
    }
  }

class MarkbookRequest{
  static Future<List<Subject>?> getMarkbookSubjects({String? termId}) async{
    if(storage.DataCache.getIsDemoAccount()!){
      return <Subject>[
        Subject(false, 1, 'DEMO tantárgy 1', 0, 4, 0),
        Subject(true, 4, 'DEMO szellemjegy', 1, 0, 0),
      ];
    }
    else if(storage.DataCache.getHasICSFile() ?? false){ return []; }

    final activeTermId = termId ?? storage.DataCache.getSelectedTermId();

    // --- MODERN API ÁG (Közvetlen és gyors feldolgozás) ---
    if (storage.DataCache.getIsModernApi()) {
      try {
        final token = await storage.DataCache.getAccessToken();
        String baseUrl = storage.DataCache.getInstituteUrl() ?? '';

        // 1. Resolve term GUID
        List<Term> terms = await TermsRequest.getTerms();
        String effectiveTermGuid = '';

        if (activeTermId != null && activeTermId.isNotEmpty) {
          for (var t in terms) {
            if (t.id == activeTermId || t.termName == activeTermId || t.termName == storage.DataCache.getSelectedTermName()) {
              effectiveTermGuid = t.id;
              break;
            }
          }
          if (effectiveTermGuid.isEmpty && activeTermId.contains('-') && activeTermId.length > 20) {
            effectiveTermGuid = activeTermId;
          }
        }

        if (effectiveTermGuid.isEmpty && terms.isNotEmpty) {
          effectiveTermGuid = terms.last.id;
        }

        // 2. Felvett tárgyak és kurzusok lekérése
        dynamic rawData;

        // A) Próbálkozás a TakenSubjects végponttal
        String subjectsUrlStr = "$baseUrl/api/TakenSubjects?sortAndPage.firstRow=0&sortAndPage.lastRow=100&sortAndPage.subjectName=asc";
        if (effectiveTermGuid.isNotEmpty) {
          subjectsUrlStr = "$baseUrl/api/TakenSubjects?request.termId=$effectiveTermGuid&sortAndPage.firstRow=0&sortAndPage.lastRow=100&sortAndPage.subjectName=asc";
        }
        try {
          final subjectsUrl = Uri.parse(subjectsUrlStr);
          final subjectsResponse = await _APIRequest.getRequest(subjectsUrl, bearerToken: token!);
          final subjectsDecoded = conv.json.decode(subjectsResponse);
          if (subjectsDecoded['data'] != null && subjectsDecoded['data'] is List && (subjectsDecoded['data'] as List).isNotEmpty) {
            rawData = subjectsDecoded['data'];
          }
        } catch (_) {}

        // B) Ha a TakenSubjects üres, próbálkozás a RegisteredCourses végponttal (Felvett kurzusok)
        if (rawData == null || (rawData is List && rawData.isEmpty)) {
          String regUrlStr = "$baseUrl/api/RegisteredCourses/GetRegisteredCourses?sortAndPage.subjectName=asc";
          if (effectiveTermGuid.isNotEmpty) {
            regUrlStr = "$baseUrl/api/RegisteredCourses/GetRegisteredCourses?request.termId=$effectiveTermGuid&sortAndPage.subjectName=asc";
          }
          try {
            final regUrl = Uri.parse(regUrlStr);
            final regResponse = await _APIRequest.getRequest(regUrl, bearerToken: token!);
            final regDecoded = conv.json.decode(regResponse);
            if (regDecoded['data'] != null && regDecoded['data'] is List && (regDecoded['data'] as List).isNotEmpty) {
              rawData = regDecoded['data'];
            }
          } catch (_) {}
        }

        // C) Tartalék: TakenSubjects félév-szűrés nélkül
        if (rawData == null || (rawData is List && rawData.isEmpty)) {
          try {
            final fallbackUrl = Uri.parse("$baseUrl/api/TakenSubjects?sortAndPage.firstRow=0&sortAndPage.lastRow=100&sortAndPage.subjectName=asc");
            final fallbackRes = await _APIRequest.getRequest(fallbackUrl, bearerToken: token!);
            final fbDecoded = conv.json.decode(fallbackRes);
            if (fbDecoded['data'] != null && fbDecoded['data'] is List && (fbDecoded['data'] as List).isNotEmpty) {
              rawData = fbDecoded['data'];
            }
          } catch (_) {}
        }

        // D) Tartalék: RegisteredCourses félév-szűrés nélkül
        if (rawData == null || (rawData is List && rawData.isEmpty)) {
          try {
            final fallbackUrl = Uri.parse("$baseUrl/api/RegisteredCourses/GetRegisteredCourses?sortAndPage.subjectName=asc");
            final fallbackRes = await _APIRequest.getRequest(fallbackUrl, bearerToken: token!);
            final fbDecoded = conv.json.decode(fallbackRes);
            if (fbDecoded['data'] != null && fbDecoded['data'] is List && (fbDecoded['data'] as List).isNotEmpty) {
              rawData = fbDecoded['data'];
            }
          } catch (_) {}
        }

        Map<String, Subject> modernSubjectsMap = {};

        if (rawData != null && rawData is List) {
          for (var item in rawData) {
            if (item is! Map) continue;
            String subjectName = item['subjectName'] ?? item['name'] ?? item['subjectCode'] ?? 'Ismeretlen tárgy';
            String subjectCode = item['subjectCode']?.toString() ?? subjectName;
            int credit = (item['subjectCredit'] as num?)?.toInt() ?? (item['credit'] as num?)?.toInt() ?? 0;
            
            bool isCompleted = item['completed'] == true || item['isCompleted'] == true || item['passed'] == true;
            int grade = (item['grade'] as num?)?.toInt() ?? (item['resultValue'] as num?)?.toInt() ?? 0;
            int failState = 0;

            if (item['uiDisplayState'] != null && item['uiDisplayState'] is Map) {
              final ui = item['uiDisplayState'];
              int uiType = (ui['type'] as num?)?.toInt() ?? 0;
              if (uiType == 1) {
                isCompleted = true;
              }
              if (ui['reasons'] != null && ui['reasons'] is List) {
                for (var r in ui['reasons']) {
                  final rStr = r.toString().toLowerCase();
                  if (rStr.contains('teljesített') || rStr.contains('aláírva')) {
                    isCompleted = true;
                  }
                  if (rStr.contains('megtagadva') || rStr.contains('nem teljesített')) {
                    failState = 1;
                  }
                  final parsedG = parseTextToGrade(r.toString());
                  if (parsedG > 0) {
                    grade = parsedG;
                  }
                }
              }
            }

            if (isCompleted && grade == 0) {
              grade = 5;
            }

            if (modernSubjectsMap.containsKey(subjectCode)) {
              final existing = modernSubjectsMap[subjectCode]!;
              if (isCompleted) existing.completed = true;
              if (grade > existing.grade) existing.grade = grade;
              if (credit > existing.credit) existing.credit = credit;
              if (failState > existing.failState) existing.failState = failState;
            } else {
              modernSubjectsMap[subjectCode] = Subject(isCompleted, credit, subjectName, 0, grade, failState);
            }
          }
        }
        return modernSubjectsMap.values.toList();
      } catch (e) {
        debug.log("Hiba a modern tárgyak lekérésekor: $e");
        return [];
      }
    }

    // --- RÉGI API ÁG (Ahol még él a /MobileService.svc) ---
    int oldTermId = int.tryParse(activeTermId ?? '0') ?? 0;
    String responseJson = await _getMarkbookJSon(oldTermId);
    List<dynamic> markbooklistRaw = [];
    final decoded = conv.json.decode(responseJson);
    if (decoded['MarkBookList'] == null) return null;
    markbooklistRaw = decoded['MarkBookList'];

    if(responseJson.isEmpty || markbooklistRaw.isEmpty){ return null; }

    List<Subject> subjects = [];
    for (var markbook in markbooklistRaw){
      final markbookMap = markbook as Map<String, dynamic>;
      subjects.add(Subject(
          markbookMap['Completed'], markbookMap['Credit'], markbookMap['SubjectName'],
          markbookMap['ID'], parseTextToGrade(markbookMap['Values']), parseTextToFailstate(markbookMap['Signer'])
      ));
    }
    return subjects;
  }

  static Future<String> _getMarkbookJSon([int termId = 0]) async{
    final username = storage.DataCache.getUsername();
    final password = storage.DataCache.getPassword();
    final url = Uri.parse(storage.DataCache.getInstituteUrl()! + URLs.MARKBOOK_URL);
    final json = '{"UserLogin":"$username","Password":"$password","CurrentPage":1,"filter":{"TermID": $termId},"TotalRowCount":-1}';
    return await _APIRequest.postRequest(url, json);
  }

  static int parseTextToFailstate(String failstate){
    RegExp regex = RegExp(r'(aláírva|megtagadva)');
    final matches = regex.allMatches(failstate.toLowerCase());
    if(matches.isEmpty) return 0;
    int best = 99;
    for(var match in matches){
      final result = (match.group(1) ?? '').trim().toLowerCase();
      if(result.isEmpty) return 0;
      switch (result){
        case "megtagadva": if(best > 1) best = 1; break;
        default: if(best > 0) best = 0; break;
      }
    }
    return best;
  }

  static bool isMark(String txt){
    switch(txt){
      case 'jeles': case 'jó': case 'közepes': case 'elégséges': case 'elégtelen': return true;
      default: return false;
    }
  }

  static int parseTextToGrade(String gradeTxt){
    RegExp regex = RegExp(r'(elégtelen|elégséges|közepes|jó|jeles|megfelelt)');
    final matches = regex.allMatches(gradeTxt.toLowerCase());
    if(matches.isEmpty) return 0;

    int latest = 0;
    for(var match in matches){
      final result = (match.group(1) ?? '').trim().toLowerCase();
      if(result.isEmpty) break;
      switch (result){
        case 'jeles': latest = 5; break;
        case 'jó': latest = 4; break;
        case 'közepes': latest = 3; break;
        case 'elégséges': latest = 2; break;
        case 'elégtelen': latest = 1; break;
        case 'megfelelt': latest = 5; break; // Pipa megjelenítéséhez
      }
    }
    return latest;
  }
}

class CashinRequest{
  static Future<List<CashinEntry>?> getCashin() => getAllCashins();

  static String _normalizeText(String s) {
    return s.toLowerCase()
        .replaceAll('á', 'a')
        .replaceAll('é', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ö', 'o')
        .replaceAll('ő', 'o')
        .replaceAll('ú', 'u')
        .replaceAll('ü', 'u')
        .replaceAll('ű', 'u')
        .replaceAll(RegExp(r'\.{2,}'), '');
  }

  static bool _isIgnoredTransaction(String text) {
    final norm = _normalizeText(text);
    return norm.contains('utalas a gyujtoszamlara') ||
        norm.contains('utalas a gyujto') ||
        (norm.contains('utalas') && norm.contains('gyujto'));
  }

  static bool _isPositiveIncome(String text) {
    final norm = _normalizeText(text);
    return norm.contains('kozeleti') ||
        norm.contains('intezmenyi szakmai') ||
        norm.contains('tudomanyos') ||
        norm.contains('rendszeres szocialis') ||
        norm.contains('rendkivuli szocialis') ||
        norm.contains('egyszeri szocialis') ||
        norm.contains('tamogatas') ||
        norm.contains('hok rendszeres oszt') ||
        norm.contains('hok.rend.szoc') ||
        norm.contains('hok') ||
        norm.contains('osztondij') ||
        norm.contains('kifizetes') ||
        norm.contains('jovairas') ||
        norm.contains('jutalom');
  }

  static Future<List<Map<String, dynamic>>> getScholarshipPayments() async {
    if (storage.DataCache.getIsModernApi()) {
      try {
        final token = await storage.DataCache.getAccessToken();
        String baseUrl = storage.DataCache.getInstituteUrl() ?? '';
        final url = Uri.parse("$baseUrl/api/Scholarship/GetScholarshipPayments?sortAndPage.firstRow=0&sortAndPage.lastRow=100&sortAndPage.termId=desc");
        final responseRaw = await _APIRequest.getRequest(url, bearerToken: token!);
        final decoded = conv.json.decode(responseRaw);
        if (decoded['data'] != null && decoded['data'] is List) {
          return List<Map<String, dynamic>>.from(decoded['data']);
        }
      } catch (e) {
        debug.log("Hiba az ösztöndíjak lekérésekor: $e");
      }
    }
    return [];
  }

  static Future<List<CashinEntry>?> getAllCashins() async{
    if(storage.DataCache.getIsDemoAccount()!){
      final now = DateTime.now();
      return <CashinEntry>[
        CashinEntry(10000, DateTime(now.year + 1, now.month).millisecondsSinceEpoch, 'DEMO befizetés 1', "1", 'aktív'),
        CashinEntry(70, DateTime(now.year + 1, now.month).millisecondsSinceEpoch, 'DEMO befizetés 2', "2", 'teljesített'),
      ];
    }
    else if(storage.DataCache.getHasICSFile() ?? false){
      return [];
    }

    if (storage.DataCache.getIsModernApi()) {
      try {
        final token = await storage.DataCache.getAccessToken();
        String baseUrl = storage.DataCache.getInstituteUrl() ?? '';

        final txUrl = Uri.parse("$baseUrl/api/Transactions/GetStudentPreviousTransactions?sortAndPage.firstRow=0&sortAndPage.lastRow=100&sortAndPage.transferDate=desc");

        final results = await Future.wait([
          _APIRequest.getRequest(txUrl, bearerToken: token!),
          getScholarshipPayments(),
        ]);

        final responseRaw = results[0] as String;
        final scholarships = results[1] as List<Map<String, dynamic>>;
        final decoded = conv.json.decode(responseRaw);

        List<CashinEntry> modernCashins = [];
        Set<String> processedTxIds = {};

        if (decoded['data'] != null && decoded['data'] is List) {
          for (var item in decoded['data']) {
            final rawVal = item['transactionValue'];
            int rawAmount = ((rawVal as num?) ?? 0).toInt().abs();
            final payingType = item['transactionPayingType']?.toString() ?? '';
            final dir = item['transactionDirection']?.toString() ?? '';
            final note = item['transactionNote']?.toString() ?? '';
            final status = item['transactionStatus']?.toString() ?? '';
            final txId = item['transactionId']?.toString() ?? 'ismeretlen_id';

            final combined = "$payingType $dir $note";
            final bool ignored = _isIgnoredTransaction(combined);
            final bool isIncome = !ignored && _isPositiveIncome(combined);

            int amount = isIncome ? rawAmount : -rawAmount;

            final rawDate = item['transferDate']?.toString();
            final dateMs = rawDate != null ? (DateTime.tryParse(rawDate)?.millisecondsSinceEpoch ?? 0) : 0;

            String displayTitle = payingType.isNotEmpty ? payingType : 'Tranzakció';
            String? displayNote = note.isNotEmpty ? note : null;

            // Ösztöndíj esetén keressük meg a pontos, részletes nevet
            if (isIncome && scholarships.isNotEmpty) {
              for (var s in scholarships) {
                final sAmount = ((s['amount'] as num?) ?? 0).toInt().abs();
                if (sAmount == rawAmount) {
                  final sName = s['name']?.toString() ?? '';
                  final sType = s['titleType']?.toString() ?? '';
                  if (sName.isNotEmpty) {
                    displayTitle = sName;
                    displayNote = sType.isNotEmpty ? sType : displayNote;
                    break;
                  }
                }
              }
            }

            processedTxIds.add(txId);

            modernCashins.add(CashinEntry(
              amount,
              dateMs,
              displayTitle,
              txId,
              status,
              direction: dir.isNotEmpty ? dir : null,
              note: displayNote,
              currency: item['transactionCurrency']?.toString() ?? 'HUF',
              isIgnored: ignored,
            ));
          }
        }

        // Ha a Scholarship végponton van olyan ösztöndíj, ami még nem volt a tranzakciók között
        for (var s in scholarships) {
          final sId = s['id']?.toString() ?? '';
          if (sId.isNotEmpty && !processedTxIds.contains(sId)) {
            final sAmount = ((s['amount'] as num?) ?? 0).toInt().abs();
            final sName = s['name']?.toString() ?? 'Ösztöndíj';
            final sType = s['titleType']?.toString() ?? '';
            final rawDate = (s['bankDate'] ?? s['latestExecutionDate'])?.toString();
            final dateMs = rawDate != null ? (DateTime.tryParse(rawDate)?.millisecondsSinceEpoch ?? 0) : 0;
            final isDone = (s['uiDisplayState'] != null && s['uiDisplayState']['type'] == 1) || s['bankDate'] != null;

            modernCashins.add(CashinEntry(
              sAmount,
              dateMs,
              sName,
              sId,
              isDone ? 'teljesített' : 'aktív',
              direction: 'Ösztöndíj kifizetés',
              note: sType.isNotEmpty ? sType : null,
              currency: s['currencyName']?.toString() ?? 'HUF',
              isIgnored: false,
            ));
          }
        }

        return modernCashins;
      } catch (e) {
        debug.log("Hiba a modern tranzakciók lekérésekor: $e");
        return [];
      }
    }

    final username = storage.DataCache.getUsername();
    final password = storage.DataCache.getPassword();
    final json = '{"UserLogin":"$username","Password":"$password","TotalRowCount":-1}';
    final url = Uri.parse(storage.DataCache.getInstituteUrl()! + URLs.GETCASHIN_URL);

    List<CashinEntry> entries = _jsonToCashinEntry(await _APIRequest.postRequest(url, json));
    return entries;
  }

  static List<CashinEntry> _jsonToCashinEntry(String json){
    if(storage.DataCache.getIsDemoAccount()!){ return []; }
    List<CashinEntry> ls = [];
    try {
      final List<dynamic> cashins = conv.json.decode(json)['CashinDataRows'];
      for (var cashin in cashins) {
        int rawAmount = ((cashin['amount'] as num?) ?? 0).toInt().abs();
        final name = cashin['appellation']?.toString() ?? '';
        final bool ignored = _isIgnoredTransaction(name);
        final bool isIncome = !ignored && _isPositiveIncome(name);
        int amount = isIncome ? rawAmount : -rawAmount;

        ls.add(CashinEntry(
            amount,
            int.parse(cashin['deadline'] == null ? '0' : cashin['deadline'].toString().replaceAll('/Date(', '').replaceAll(')/', '')),
            name,
            cashin['ID'].toString(),
            cashin['status_name'],
            isIgnored: ignored,
        ));
      }
    }
    catch (_){ return []; }
    return ls;
  }

  static Future<double?> getCollectiveInvoiceBalance() async {
    if (storage.DataCache.getIsDemoAccount()!) {
      await storage.DataCache.setAccountBalance(15000.0, currency: 'HUF');
      return 15000.0;
    }
    if (storage.DataCache.getIsModernApi()) {
      try {
        final token = await storage.DataCache.getAccessToken();
        String baseUrl = storage.DataCache.getInstituteUrl() ?? '';
        final url = Uri.parse("$baseUrl/api/FinancialDataDashboard/GetCollectiveInvoices");
        final responseRaw = await _APIRequest.getRequest(url, bearerToken: token!);
        final decoded = conv.json.decode(responseRaw);
        if (decoded['data'] != null && decoded['data'] is List && (decoded['data'] as List).isNotEmpty) {
          final first = decoded['data'][0];
          final balance = (first['collectiveInvoiceBalance'] as num?)?.toDouble() ?? 0.0;
          final currency = first['collectiveInvoiceCurrency']?.toString() ?? 'HUF';
          await storage.DataCache.setAccountBalance(balance, currency: currency);
          return balance;
        }
      } catch (e) {
        debug.log("Hiba a gyűjtőszámla egyenleg lekérésekor: $e");
      }
    }
    return storage.DataCache.getAccountBalance();
  }
}

class PeriodsRequest{

  static Future<List<PeriodEntry>?> getPeriods({String? termId}) async{
    if(storage.DataCache.getIsDemoAccount()!){
      final now = DateTime.now();
      return <PeriodEntry>[
        PeriodEntry('lejárt időszak', DateTime(now.year - 1, now.month, now.day - 2).millisecondsSinceEpoch, DateTime(now.year - 1, now.month, now.day + 1).millisecondsSinceEpoch, 1),
        PeriodEntry('bejelentkezési időszak', DateTime(now.year, now.month, now.day - 2).millisecondsSinceEpoch, DateTime(now.year, now.month, now.day +7).millisecondsSinceEpoch, 1),
      ];
    }
    else if(storage.DataCache.getHasICSFile() ?? false){
      return [PeriodEntry('végleges tárgyjelentkezés', await ICSCalendar.getFirstEventStartMs(), await ICSCalendar.getFirstEventStartMs() + Duration(days: 365).inMilliseconds, 1)];
    }

    final activeTermId = termId ?? storage.DataCache.getSelectedTermId();

    // --- MODERN API ÁG ---
    if (storage.DataCache.getIsModernApi()) {
      try {
        final token = await storage.DataCache.getAccessToken();
        String baseUrl = storage.DataCache.getInstituteUrl() ?? '';

        List<Term> terms = await TermsRequest.getTerms();
        String effectiveTermGuid = '';

        if (activeTermId != null && activeTermId.isNotEmpty) {
          for (var t in terms) {
            if (t.id == activeTermId || t.termName == activeTermId || t.termName == storage.DataCache.getSelectedTermName()) {
              effectiveTermGuid = t.id;
              break;
            }
          }
          if (effectiveTermGuid.isEmpty && activeTermId.contains('-') && activeTermId.length > 20) {
            effectiveTermGuid = activeTermId;
          }
        }

        if (effectiveTermGuid.isEmpty && terms.isNotEmpty) {
          effectiveTermGuid = terms.last.id;
        }

        if (effectiveTermGuid.isEmpty) return [];

        // 3. Időszakok lekérése az adott félévhez
        String periodsUrlStr = "$baseUrl/api/Periods/GetPeriods?sortAndPage.firstRow=0&sortAndPage.lastRow=50&sortAndPage.fromDate=asc";
        if (effectiveTermGuid.isNotEmpty) {
          periodsUrlStr = "$baseUrl/api/Periods/GetPeriods?request.termId=$effectiveTermGuid&sortAndPage.firstRow=0&sortAndPage.lastRow=50&sortAndPage.fromDate=asc";
        }
        final periodsUrl = Uri.parse(periodsUrlStr);
        final periodsResponse = await _APIRequest.getRequest(periodsUrl, bearerToken: token!);
        var periodsDecoded = conv.json.decode(periodsResponse);

        if ((periodsDecoded['data'] == null || (periodsDecoded['data'] is List && (periodsDecoded['data'] as List).isEmpty)) && effectiveTermGuid.isNotEmpty) {
          final fallbackUrl = Uri.parse("$baseUrl/api/Periods/GetPeriods?sortAndPage.firstRow=0&sortAndPage.lastRow=50&sortAndPage.fromDate=asc");
          final fallbackRes = await _APIRequest.getRequest(fallbackUrl, bearerToken: token);
          final fbDecoded = conv.json.decode(fallbackRes);
          if (fbDecoded['data'] != null && fbDecoded['data'] is List && (fbDecoded['data'] as List).isNotEmpty) {
            periodsDecoded = fbDecoded;
          }
        }

        List<PeriodEntry> modernPeriods = [];
        if (periodsDecoded['data'] != null && periodsDecoded['data'] is List) {
          for (var item in periodsDecoded['data']) {
            final fromStr = item['fromDate']?.toString();
            final toStr = item['toDate']?.toString();
            if (fromStr == null || toStr == null) continue;

            final fromEpoch = DateTime.tryParse(fromStr)?.millisecondsSinceEpoch ?? 0;
            final toEpoch = DateTime.tryParse(toStr)?.millisecondsSinceEpoch ?? 0;

            final pName = item['periodName']?.toString() ?? item['periodType']?.toString() ?? 'Ismeretlen időszak';

            modernPeriods.add(PeriodEntry(
                pName,
                fromEpoch,
                toEpoch,
                1 // partOfSemester fake adat (nem használja igazán a UI)
            ));
          }
        }
        return modernPeriods;

      } catch (e) {
        debug.log("Hiba a modern időszakok lekérésekor: $e");
        return [];
      }
    }

    // --- RÉGI API ÁG ---
    List<Term> terms = [];
    if (activeTermId != null && activeTermId.isNotEmpty) {
      terms = [Term(activeTermId, storage.DataCache.getSelectedTermName() ?? '')];
    } else {
      terms = await TermsRequest.getTerms();
    }
    if(terms.isEmpty) return <PeriodEntry>[PeriodEntry('Hiba lépett fel!\nNincs term id.', DateTime.now().millisecondsSinceEpoch, DateTime.now().millisecondsSinceEpoch, 1)];

    List<PeriodEntry> periods = <PeriodEntry>[];
    int cntperiod = terms.length;
    for(var term in terms){
      final jsonresult = await _getPeriodJSon(term.intId);
      final decoded = conv.json.decode(jsonresult);
      if (decoded['PeriodList'] != null) {
        final result = decoded['PeriodList'] as List<dynamic>;
        for(var period in result){
          final currPeriod = period as Map<String, dynamic>;
          periods.add(PeriodEntry(currPeriod['PeriodTypeName'], int.parse(currPeriod['FromDate'].toString().replaceAll('/Date(', '').replaceAll(')/', '')), int.parse(currPeriod['ToDate'].toString().replaceAll('/Date(', '').replaceAll(')/', '')), cntperiod));
        }
      }
      cntperiod--;
    }
    return periods;
  }

  static Future<String> _getPeriodJSon(int termID) async{
    final username = storage.DataCache.getUsername();
    final password = storage.DataCache.getPassword();
    final url = Uri.parse(storage.DataCache.getInstituteUrl()! + URLs.PERIODS_URL);
    final json = '{"UserLogin":"$username","Password":"$password","PeriodTermID":$termID,"TotalRowCount":-1}';
    return await _APIRequest.postRequest(url, json);
  }
}

class MailRequest{
  static Future<int> getUnreadMessageCount() async {
    if (storage.DataCache.getIsDemoAccount()!) {
      await storage.DataCache.setUnreadMailCount(1);
      return 1;
    }
    if (storage.DataCache.getIsModernApi()) {
      try {
        final token = await storage.DataCache.getAccessToken();
        String baseUrl = storage.DataCache.getInstituteUrl() ?? '';
        final url = Uri.parse("$baseUrl/api/Message/GetUnreadedMessagesCount");
        final responseRaw = await _APIRequest.getRequest(url, bearerToken: token!);
        final decoded = conv.json.decode(responseRaw);
        if (decoded['data'] != null && decoded['data']['count'] != null) {
          int count = (decoded['data']['count'] as num).toInt();
          await storage.DataCache.setUnreadMailCount(count);
          return count;
        }
      } catch (e) {
        debug.log("Hiba az olvasatlan üzenetek számának lekérésekor: $e");
      }
    }
    return storage.DataCache.getUnreadMailCount();
  }

  static Future<List<int>> getUnreadMessagesAndAllMessages()async{
    try{
      if (storage.DataCache.getIsModernApi()) {
        final unread = await getUnreadMessageCount();
        return [unread, 0, 0];
      }
      List<int> list = [];
      final json = await _getMailJson(0);
      var result = conv.json.decode(json)['NewMessagesNumber'];
      list.add(result);
      result = conv.json.decode(json)['TotalRowCount'];
      list.add(result);
      return list;
    }
    catch(_){
      return [0, 0, 0];
    }
  }

  static Future<List<MailEntry>?> getMails(int page) async{
    if(storage.DataCache.getIsDemoAccount()!){
      final now = DateTime.now();
      return <MailEntry>[
        MailEntry('Tárgy', 'Szöveg', 'DEMO feladó', now.subtract(const Duration(hours: 1)).millisecondsSinceEpoch, false, "0"),
        MailEntry('DEMO', 'Demo Demo Demo', 'DEMO feladó', now.subtract(const Duration(hours: 2)).millisecondsSinceEpoch, false, "1"),
      ];
    }
    else if(storage.DataCache.getHasICSFile() ?? false){
      return [];
    }

    if (storage.DataCache.getIsModernApi()) {
      try {
        final token = await storage.DataCache.getAccessToken();
        String baseUrl = storage.DataCache.getInstituteUrl() ?? '';

        int actualPage = page > 0 ? page - 1 : 0;
        int firstRow = actualPage * 20;
        int lastRow = firstRow + 20;

        final url = Uri.parse("$baseUrl/api/Message/GetReceivedMessages?firstRow=$firstRow&lastRow=$lastRow&filterType=0");
        final responseRaw = await _APIRequest.getRequest(url, bearerToken: token!);
        final decoded = conv.json.decode(responseRaw);

        List<MailEntry> modernMails = [];
        if (decoded['data'] != null && decoded['data']['receivedMessages'] != null) {
          for (var item in decoded['data']['receivedMessages']) {
            modernMails.add(MailEntry(
              item['subject'] ?? "Nincs tárgy",
              "A szöveg letöltéséhez kattints ide...",
              item['senderName'] ?? "Ismeretlen",
              DateTime.parse(item['lastPostDate']).millisecondsSinceEpoch,
              item['unreadedPostCount'] == 0,
              item['messageId'].toString(),
            ));
          }
        }
        return modernMails;
      } catch (e) {
        debug.log("Hiba a modern üzenetek lekérésekor: $e");
        return [];
      }
    }

    final request = await _getMailJson(page);
    List<MailEntry> mails = getMailEntrysJson(request);
    return mails;
  }

  static Future<String> _getMailJson(int page)async{
    final username = storage.DataCache.getUsername();
    final password = storage.DataCache.getPassword();
    final url = Uri.parse(storage.DataCache.getInstituteUrl()! + URLs.MESSAGES_URL);
    final json = '{"UserLogin":"$username","Password":"$password","CurrentPage":$page,"TotalRowCount":-1,"MessageID":0,"MessageSortEnum":0}';
    return await _APIRequest.postRequest(url, json);
  }

  static List<MailEntry> getMailEntrysJson(String json){
    List<MailEntry> mails = [];
    final decoded = conv.json.decode(json);
    if (decoded['MessagesList'] == null) return [];
    final result = decoded['MessagesList'] as List<dynamic>;

    for(var item in result){
      mails.add(MailEntry(item['Subject'], removeBloatFromMail(item['Detail']), item['Name'], int.parse(item['SendDate'].toString().replaceAll('\/Date(', '').replaceAll(')\/', '')), !item['IsNew'], item['PersonMessageId'].toString()));
    }
    return mails;
  }

  static String removeBloatFromMail(String raw){
    var sanitised = raw.trim();
    sanitised = sanitised.replaceAll(RegExp(r'\.\w+\{[^}]*\}'), '');
    return sanitised.trim();
  }

  static Future<bool> setMailRead(String id, {String? postId}) async {
    if (storage.DataCache.getIsDemoAccount() ?? false) {
      return true;
    }
    if (storage.DataCache.getIsModernApi()) {
      try {
        final token = await storage.DataCache.getAccessToken();
        String baseUrl = storage.DataCache.getInstituteUrl() ?? '';
        String? targetPostId = postId;

        if (targetPostId == null || targetPostId.isEmpty) {
          final postsUrl = Uri.parse("$baseUrl/api/Messages/$id/Posts?messageId=$id");
          String postsRaw = await _APIRequest.getRequest(postsUrl, bearerToken: token!);
          final postsDecoded = conv.json.decode(postsRaw);
          if (postsDecoded['data'] != null && postsDecoded['data']['posts'] != null) {
            final postsList = postsDecoded['data']['posts'] as List<dynamic>;
            for (var p in postsList) {
              if (p['isRead'] == false && p['postId'] != null) {
                targetPostId = p['postId'].toString();
                break;
              }
            }
            if (targetPostId == null && postsList.isNotEmpty && postsList[0]['postId'] != null) {
              targetPostId = postsList[0]['postId'].toString();
            }
          }
        }

        if (targetPostId != null && targetPostId.isNotEmpty) {
          final processedUrl = Uri.parse("$baseUrl/api/Messages/$id/Posts/Processed");
          final body = conv.jsonEncode({"postIds": [targetPostId]});
          await _APIRequest.postRequestWithRetry(processedUrl, body);
          await getUnreadMessageCount();
          return true;
        }
      } catch (e) {
        debug.log("Hiba az üzenet olvasottá tétele során: $e");
      }
    }
    return false;
  }

  static Future<String> getMailContent(String messageId, String oldDetails) async {
    if (storage.DataCache.getIsDemoAccount() ?? false) {
      return oldDetails;
    }

    if (storage.DataCache.getIsModernApi()) {
      try {
        final token = await storage.DataCache.getAccessToken();
        String baseUrl = storage.DataCache.getInstituteUrl() ?? '';
        final url = Uri.parse("$baseUrl/api/Messages/$messageId/Posts?messageId=$messageId");

        String responseRaw = await _APIRequest.getRequest(url, bearerToken: token!);

        // retry if 500 status
        if (responseRaw.contains("Hiba történt") || responseRaw.contains('"statusCode":500')) {
          await Future.delayed(const Duration(milliseconds: 200)); // Vár egy picit
          responseRaw = await _APIRequest.getRequest(url, bearerToken: token); // Újra beküldi
        }
        // ---------------------------------------------------

        final decoded = conv.json.decode(responseRaw);

        if (decoded['data'] != null && decoded['data']['posts'] != null && decoded['data']['posts'].isNotEmpty) {
          final firstPost = decoded['data']['posts'][0];
          final postId = firstPost['postId']?.toString();
          if (postId != null && firstPost['isRead'] != true) {
            // Automatically mark processed on server!
            setMailRead(messageId, postId: postId);
          }
          String rawHtml = firstPost['htmlText'] ?? "";
          String cleanText = rawHtml
              .replaceAll(RegExp(r'<style[^>]*>[\s\S]*?</style>'), '')
              .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
              .replaceAll(RegExp(r'</p>'), '\n\n')
              .replaceAll(RegExp(r'<[^>]*>'), '')
              .replaceAll('&nbsp;', ' ')
              .trim();
          return cleanText;
        } else {
          return "Üres válasz érkezett a Neptuntól.\n\nSzerver válasza: $responseRaw";
        }
      } catch (e) {
        return "Hálózati hiba a letöltés során:\n$e";
      }
    }
    return oldDetails;
  }
}
  
  class Term{
    String id;
    String termName;

    Term(dynamic id, this.termName) : id = id.toString();

    int get intId => int.tryParse(id) ?? 0;

    Map<String, dynamic> toMap() => {'id': id, 'termName': termName};
    factory Term.fromMap(Map<String, dynamic> map) => Term(map['id']?.toString() ?? '', map['termName']?.toString() ?? '');

    String serialize() => conv.jsonEncode(toMap());
    factory Term.deserialize(String str) => Term.fromMap(conv.jsonDecode(str));
  }
  
  class Subject{
    bool completed;
    int credit;
    int id;
    String name;
    int grade = 0;
    int failState = 0;
  
  
    Subject(this.completed, this.credit, this.name, this.id, this.grade, this.failState);
  
    @override
    String toString() {
      return '$completed\n$credit\n$id\n$name\n$grade\n$failState';
    }
  
    Subject fillWithExisting(String existing){
      var data = existing.split('\n');
      if(data.length < 6){
        completed = false;
        credit = 0;
        id = 0;
        name = 'ERROR';
        grade = 0;
        failState = 1;
        return this;
      }
      completed = bool.parse(data[0]);
      credit = int.parse(data[1]);
      id = int.parse(data[2]);
      name = data[3];
      grade = int.parse(data[4]);
      failState = int.parse(data[5]);
      return this;
    }
  }
  
  class Institute{
    late final String Name;
    late final String URL;
  
    Institute(String name, String url){
      Name = name;
      URL = url;
    }
  
    getUrl() => Uri.parse(URL);
  }
class CalendarEntry {
  late int startEpoch;
  late int endEpoch;
  late String location;
  late String title;

  late int eventType;

  late String subjectCode;
  late String teacher;
  late String? courseType;
  late String? classInstanceId;
  late String? taskId;

  bool get isExam => eventType == 1;
  bool get isTask => eventType > 1;

  CalendarEntry(String start, String end, String loc, String rawTitle, bool oldIsExam) {
    startEpoch = int.parse(start);
    startEpoch = DateTime.fromMillisecondsSinceEpoch(startEpoch)
        .subtract(Duration(hours: (Generic.isDaylightSavings(DateTime.fromMillisecondsSinceEpoch(startEpoch)) ? 2 : 1)))
        .millisecondsSinceEpoch;

    endEpoch = int.parse(end);
    endEpoch = DateTime.fromMillisecondsSinceEpoch(endEpoch)
        .subtract(Duration(hours: (Generic.isDaylightSavings(DateTime.fromMillisecondsSinceEpoch(endEpoch)) ? 2 : 1)))
        .millisecondsSinceEpoch;

    location = loc;
    classInstanceId = null;
    eventType = oldIsExam ? 1 : 0;

    final regex = RegExp(r'\]([^(]+)\(');
    final match = regex.firstMatch(rawTitle);
    if (match != null) {
      title = match.group(1)!.replaceAll(']', '').replaceAll('(', '').replaceAll('\u0009', '').trim();
    } else {
      title = rawTitle;
    }

    final regex2 = RegExp(r'\(([^)]+)\)');
    final matches = regex2.allMatches(rawTitle).map((m) => m.group(1)!.trim()).toList();
    if (matches.isNotEmpty) {
      subjectCode = matches[0];
    } else {
      subjectCode = "-";
    }

    if (matches.length > 2) {
      courseType = matches[1];
      teacher = matches[2];
    } else if (matches.length > 1) {
      teacher = matches[1];
      courseType = null;
    } else {
      teacher = "-";
      courseType = null;
    }
  }

  // MODERN API
  CalendarEntry.fromModern({
    required this.startEpoch,
    required this.endEpoch,
    required this.location,
    required this.title,
    required this.eventType,
    required this.subjectCode,
    required this.teacher,
    this.courseType,
    this.classInstanceId,
    this.taskId,
  });

  @override
  String toString() {
    return '$startEpoch\n$endEpoch\n$location\n$title\n$eventType\n$teacher\n$subjectCode\n${classInstanceId ?? ""}\n${taskId ?? ""}\n${courseType ?? ""}';
  }

  CalendarEntry fillWithExisting(String existing) {
    var data = existing.split('\n');
    if (data.isEmpty || data.length < 7) return this;

    startEpoch = int.parse(data[0]);
    endEpoch = int.parse(data[1]);
    location = data[2];
    title = data[3];

    if (data[4] == 'true') eventType = 1;
    else if (data[4] == 'false') eventType = 0;
    else eventType = int.parse(data[4]);

    teacher = data[5];
    subjectCode = data[6];

    if (data.length >= 8 && data[7].trim().isNotEmpty) {
      classInstanceId = data[7].trim();
    } else { classInstanceId = null; }

    if (data.length >= 9 && data[8].trim().isNotEmpty) {
      taskId = data[8].trim();
    } else { taskId = null; }

    if (data.length >= 10 && data[9].trim().isNotEmpty) {
      courseType = data[9].trim();
    } else { courseType = null; }

    return this;
  }
}

class CashinEntry{
  late String ID;
  late int ammount;
  late int dueDateMs;
  late String comment;
  late bool completed = false;
  String? direction;
  String? note;
  String? currency;
  bool isIgnored = false;

  CashinEntry(this.ammount, this.dueDateMs, this.comment, this.ID, String completedStatus, {this.direction, this.note, this.currency, this.isIgnored = false}){
    final norm = completedStatus.toLowerCase();
    final isCancelled = norm.contains('erveny') || norm.contains('érvény') || norm.contains('sikertelen');
    if(!isCancelled && (
        norm.contains('teljes') ||
        norm.contains('kifizetett') ||
        norm.contains('penzugyileg igazolt') ||
        norm.contains('pénzügyileg igazolt') ||
        norm.contains('torolt') ||
        norm.contains('törölt'))){
      completed = true;
    }
  }

  @override
  String toString() {
    return '$ammount\n$dueDateMs\n$comment\n$completed\n$ID\n${direction ?? ''}\n${note ?? ''}\n${currency ?? ''}\n$isIgnored';
  }

  CashinEntry fillWithExisting(String existing){
    var data = existing.split('\n');
    if(data.isEmpty || data.length < 5){
      return this;
    }
    ammount = int.tryParse(data[0]) ?? 0;
    dueDateMs = int.tryParse(data[1]) ?? 0;
    comment = data[2];
    completed = bool.tryParse(data[3]) ?? false;
    ID = data[4];
    if (data.length > 5) direction = data[5].isNotEmpty ? data[5] : null;
    if (data.length > 6) note = data[6].isNotEmpty ? data[6] : null;
    if (data.length > 7) currency = data[7].isNotEmpty ? data[7] : null;
    if (data.length > 8) isIgnored = bool.tryParse(data[8]) ?? false;
    return this;
  }
}


  
  enum PeriodType{
    timetableRegistration,
    gradingTime,
    loginTime,
    pregivenGradingAccepting,
    timetableFinalization,
    coursesRegistration,
    nerdTime,
    examTime,
    signinTime,
    none
  }
  
  class PeriodEntry{
    late String name;
    late int startEpoch;
    late int endEpoch;
    late bool isActive;
    late int partofSemester;
    late PeriodType type;
  
    PeriodEntry(this.name, int startEpoch, int endEpoch, this.partofSemester){
      final startEp = DateTime.fromMillisecondsSinceEpoch(startEpoch);
      final correctedStartEpoch = DateTime(startEp.year, startEp.month, startEp.day);
      this.startEpoch = correctedStartEpoch.millisecondsSinceEpoch;
  
      final endEp = DateTime.fromMillisecondsSinceEpoch(endEpoch).add(const Duration(days: 1)); // last day counts too
      var correctedEndEpoch = DateTime(endEp.year, endEp.month, endEp.day);
      final isOverflowedByOneDay = endEp.add(Duration(minutes: 1)).hour == 1;
      if(isOverflowedByOneDay){
        correctedEndEpoch = correctedEndEpoch.subtract(Duration(days: 1));
      }
      this.endEpoch = correctedEndEpoch.millisecondsSinceEpoch;
  
  
      fillIsActiveStatus();
    }
  
    @override
    String toString() {
      return '$name\n$startEpoch\n$endEpoch\n$partofSemester';
    }
  
    String getValue(){
      return '$startEpoch-$endEpoch';
    }
  
    PeriodEntry fillWithExisting(String existing){
      var data = existing.split('\n');
      if(data.isEmpty || data.length < 4){
        return this;
      }
      name = data[0];
      startEpoch = int.tryParse(data[1]) ?? 0;
      endEpoch = int.parse(data[2]);
      partofSemester = int.parse(data[3]);
      fillIsActiveStatus();
      return this;
    }
  
    void fillIsActiveStatus() {
      final now = DateTime.now().millisecondsSinceEpoch;
      isActive = (startEpoch <= now && now <= endEpoch);

      final lower = name.toLowerCase().trim();
      if (lower.contains('előzetes tárgyjelentkezés') || lower.contains('tárgyfelvétel')) {
        type = PeriodType.timetableRegistration;
      } else if (lower.contains('jegybeírás') || lower.contains('értékelés')) {
        type = PeriodType.gradingTime;
      } else if (lower.contains('bejelentkezés') || lower.contains('regisztráció')) {
        type = PeriodType.loginTime;
      } else if (lower.contains('megajánlott jegy')) {
        type = PeriodType.pregivenGradingAccepting;
      } else if (lower.contains('végleges tárgyjelentkezés')) {
        type = PeriodType.timetableFinalization;
      } else if (lower.contains('kurzusjelentkezés') || lower.contains('kurzusfelvétel')) {
        type = PeriodType.coursesRegistration;
      } else if (lower.contains('szorgalmi')) {
        type = PeriodType.nerdTime;
      } else if (lower.contains('vizsga')) {
        type = PeriodType.examTime;
      } else if (lower.contains('beiratkozás')) {
        type = PeriodType.signinTime;
      } else {
        type = PeriodType.none;
      }
    }
  }

  class MailEntry{
    String subject;
    String detail;
    String senderName;
    int sendDateMs;
    bool isRead;
    String ID;

    MailEntry(this.subject, this.detail, this.senderName, this.sendDateMs, this.isRead, this.ID);

    @override
    String toString() {
      return '$subject\u0000$detail\u0000$senderName\u0000$sendDateMs\u0000$isRead\u0000$ID';
    }

    MailEntry fillWithExisting(String existing){
      var data = existing.split('\u0000');
      if(data.isEmpty || data.length < 6){
        return this;
      }
      subject = data[0];
      detail = data[1];
      senderName = data[2];
      sendDateMs = int.parse(data[3]);
      isRead = bool.parse(data[4]);
      ID = data[5];
      return this;
    }
  }
  
  class Generic {
    static String reactionForAvg(double avg) {
      if (avg >= 5.0) {
        return "💀";
      }
      else if (avg >= 4.25) {
        return "🤓";
      }
      else if (avg >= 3.75) {
        return "😌";
      }
      else if (avg >= 2.75) {
        return "😐";
      }
      else if (avg >= 2) {
        return "😬";
      }
      else if (avg > 0) {
        return "🤡";
      }
      else {
        return '🤗';
      }
    }

    static String monthToText(int month) {
      switch (month) {
        case 1:
          return AppStrings.getLanguagePack().api_monthJan_Universal;
        case 2:
          return AppStrings.getLanguagePack().api_monthFeb_Universal;
        case 3:
          return AppStrings.getLanguagePack().api_monthMar_Universal;
        case 4:
          return AppStrings.getLanguagePack().api_monthApr_Universal;
        case 5:
          return AppStrings.getLanguagePack().api_monthMay_Universal;
        case 6:
          return AppStrings.getLanguagePack().api_monthJun_Universal;
        case 7:
          return AppStrings.getLanguagePack().api_monthJul_Universal;
        case 8:
          return AppStrings.getLanguagePack().api_monthAug_Universal;
        case 9:
          return AppStrings.getLanguagePack().api_monthSep_Universal;
        case 10:
          return AppStrings.getLanguagePack().api_monthOkt_Universal;
        case 11:
          return AppStrings.getLanguagePack().api_monthNov_Universal;
        case 12:
          return AppStrings.getLanguagePack().api_monthDec_Universal;
      }
      return "NULL";
    }

    static String dayToText(int day){
      switch(day){
        case 1:
          return AppStrings.getLanguagePack().api_dayMon_Universal;
        case 2:
          return AppStrings.getLanguagePack().api_dayTue_Universal;
        case 3:
          return AppStrings.getLanguagePack().api_dayWed_Universal;
        case 4:
          return AppStrings.getLanguagePack().api_dayThu_Universal;
        case 5:
          return AppStrings.getLanguagePack().api_dayFri_Universal;
        case 6:
          return AppStrings.getLanguagePack().api_daySat_Universal;
        case 7:
          return AppStrings.getLanguagePack().api_daySun_Universal;
        default:
          return '';
      }
    }

    static String capitalizePeriodText(String periodName) {
      final chars = periodName
          .toLowerCase()
          .trim()
          .characters
          .toList();
      String str = '';
      int idx = 0;
      bool setNexttoCapitalize = false;
      for (var item in chars) {
        if (idx == 0 || setNexttoCapitalize) {
          str += item.toUpperCase();
          idx++;
          setNexttoCapitalize = false;
          continue;
        }
        if (item == ' ') {
          setNexttoCapitalize = true;
        }
        str += item;
        idx++;
      }
      return str;
    }

    static String randomLoadingComment(bool familyFriendlyMode) {
      if (!familyFriendlyMode) {
        final gen = Random().nextInt(100) % 7;
        switch (gen) {
          case 0:
            return AppStrings.getLanguagePack().api_loadingScreenHintFriendly1_Universal;
          case 1:
            return AppStrings.getLanguagePack().api_loadingScreenHintFriendly2_Universal;
          case 2:
            return AppStrings.getLanguagePack().api_loadingScreenHintFriendly3_Universal;
          case 3:
            return AppStrings.getLanguagePack().api_loadingScreenHintFriendly4_Universal;
          case 4:
            return AppStrings.getLanguagePack().api_loadingScreenHintFriendly5_Universal;
          case 5:
            return AppStrings.getLanguagePack().api_loadingScreenHintFriendly6_Universal;
          case 6:
            return AppStrings.getLanguagePack().api_loadingScreenHintFriendly7_Universal;
          default:
            return 'Neptun 2';
        }
      }
      final gen = Random().nextInt(100) % 7;
      switch (gen) {
        case 0:
          return AppStrings.getLanguagePack().api_loadingScreenHint1_Universal;
        case 1:
          return AppStrings.getLanguagePack().api_loadingScreenHint2_Universal;
        case 2:
          return AppStrings.getLanguagePack().api_loadingScreenHint3_Universal;
        case 3:
          return AppStrings.getLanguagePack().api_loadingScreenHint4_Universal;
        case 4:
          return AppStrings.getLanguagePack().api_loadingScreenHint5_Universal;
        case 5:
          return AppStrings.getLanguagePack().api_loadingScreenHint6_Universal;
        case 6:
          return AppStrings.getLanguagePack().api_loadingScreenHint7_Universal;
        default:
          return 'Neptun 2';
      }
    }
    static String randomLoadingCommentMini(bool familyFriendlyMode) {
      if (!familyFriendlyMode) {
        final gen = Random().nextInt(100) % 4;
        switch (gen) {
          case 0:
            return AppStrings.getLanguagePack().api_loadingScreenHintFriendlyMini1_Universal;
          case 1:
            return AppStrings.getLanguagePack().api_loadingScreenHintFriendlyMini2_Universal;
          case 2:
            return AppStrings.getLanguagePack().api_loadingScreenHintFriendlyMini3_Universal;
          case 3:
            return AppStrings.getLanguagePack().api_loadingScreenHintFriendlyMini4_Universal;
          default:
            return 'Neptun 2';
        }
      }
      final gen = Random().nextInt(100) % 3;
      switch (gen) {
        case 0:
          return AppStrings.getLanguagePack().api_loadingScreenHintMini1_Universal;
        case 1:
          return AppStrings.getLanguagePack().api_loadingScreenHintMini2_Universal;
        case 2:
          return AppStrings.getLanguagePack().api_loadingScreenHintMini3_Universal;
        default:
          return 'Neptun 2';
      }
    }

    static List<InlineSpan> textToInlineSpan(String text) {
      List<InlineSpan> spans = [];

      final htmlLink = RegExp(r'<a[^>]*>(.*?)</a>|https?://\S+|mailto:\S+');

      // Split the text at anchor tags using the regex pattern
      List<String> matches = htmlLink.allMatches(text)
          .map((m) => m.group(0)!)
          .toList();
      List<String> parts = text.split(htmlLink);

      for (int i = 0; i < parts.length; i++) {
        spans.add(TextSpan(text: parts[i]));
        if (i < matches.length) {
          if (matches[i].startsWith('<a')) {
            final htmlLink2 = RegExp(r'>(.*?)</a>');
            final match = htmlLink2.firstMatch(matches[i]);
            if (match == null) {
              continue;
            }
            String newText = match.group(1)!;

            if(!newText.contains('@') || !newText.contains('https://') || !newText.contains('http://')){
              final htmlLink3 = RegExp(r'href="(.*?)"');
              final match = htmlLink3.firstMatch(matches[i]);
              if (match == null) {
                break;
              }
              final url = match.group(1)!;
              spans.add(ClickableTextSpan.getNewClickableSpan(
                  ClickableTextSpan.getNewOpenLinkCallback(url), newText,
                  ClickableTextSpan.getStockStyle()));
            }
            else{
              final isMailTo = newText.contains('@') &&
                  !(newText.contains('https://') || newText.contains('http://'));

              spans.add(ClickableTextSpan.getNewClickableSpan(
                  ClickableTextSpan.getNewOpenLinkCallback(
                      isMailTo ? 'mailto:$newText' : newText.contains('www.') && !newText.contains('http:') ? 'https://$newText' : newText), newText,
                  ClickableTextSpan.getStockStyle()));
            }
          }
          else {
            // Handle URLs
            String url = matches[i];
            spans.add(ClickableTextSpan.getNewClickableSpan(
                ClickableTextSpan.getNewOpenLinkCallback(url), url,
                ClickableTextSpan.getStockStyle()));
          }
        }
      }

      return spans;
    }

    static void setupDaylightSavingsTime(){
      final now = DateTime.now();
      var probableSunday = DateTime(now.year, 3, 31, 0, 0, 0);
      if(probableSunday.weekday == 7){
        daylightSavingsTimeFrom = probableSunday;
      }
      else{
        daylightSavingsTimeFrom = probableSunday.subtract(Duration(days: probableSunday.weekday));
        if(daylightSavingsTimeFrom.hour != 0){
          daylightSavingsTimeFrom = DateTime(daylightSavingsTimeFrom.year, daylightSavingsTimeFrom.month, daylightSavingsTimeFrom.day + 1);
        }
      }

      probableSunday = DateTime(now.year, 10, 31, 0, 0, 0);
      if(probableSunday.weekday == 7){
        daylightSavingsTimeTo = probableSunday;
      }
      else{
        daylightSavingsTimeTo = probableSunday.subtract(Duration(days: probableSunday.weekday));
      }
    }

    static DateTime daylightSavingsTimeFrom = DateTime(DateTime.now().year, 3, 31, 0, 0, 0);
    static DateTime daylightSavingsTimeTo = DateTime(DateTime.now().year, 10, 27, 0, 0, 0);

    static bool isDaylightSavings(DateTime time){
      return (daylightSavingsTimeFrom.microsecondsSinceEpoch < time.microsecondsSinceEpoch && time.microsecondsSinceEpoch < daylightSavingsTimeTo.microsecondsSinceEpoch);
    }
    static Future<AppUpdateHelper?> getAppUpdateHelper() async{
      final url = Uri.parse('https://raw.githubusercontent.com/zoligamer/Neptun-Mobile-fork/refs/heads/main/appMinimumAllowedVersion.json');
      final response = await http.get(url);

      if (response.statusCode != 200) {
        return null;
      }

      Map<String, dynamic> jsonMap = conv.json.decode(response.body);
      return AppUpdateHelper(minAppVer: jsonMap["latestMinimumAllowedVerBuildNum"], minDisableVer: jsonMap["disableAppMinimumVersion"], updateUrl: jsonMap["updatePageJumper"]);
    }
  }

  class AppUpdateHelper{
    final int? minAppVer;
    final int? minDisableVer;
    final String? updateUrl;
    const AppUpdateHelper({required this.minAppVer, required this.minDisableVer, required this.updateUrl});
  }

  class Language{
    static Future<bool> checkSupportedUserLanguage()async{
      final deviceLang = Platform.localeName.split('_')[0].toLowerCase();
      // check language
      final allLang = await Language.getAllLanguages();
      return Language.getHasLanguageById(allLang, deviceLang);
    }

    static bool getHasLanguageById(List<LangPackMap>? languages, String neededId){
      if(languages == null){
        return false;
      }
      for(var item in languages){
        if(item.langId == neededId){
          return true;
        }
      }
      return false;
    }

    static Future<LanguagePack?> getLanguagePackById(List<LangPackMap>? languages, String neededID)async{
      if(languages == null){
        return null;
      }
      String? langUrl;
      for(var item in languages){
        if(item.langId == neededID){
          langUrl = item.langURL;
          break;
        }
      }
      if(langUrl == null){
        return null;
      }

      final url = Uri.parse(langUrl);
      final response = await http.get(url);
      if (response.statusCode != 200) {
        return null;
      }
      return LanguagePack.fromJson(neededID, response.body, (){}); // auto registers itself, as its downloaded, no need for the callback, def not invalid as it has just been downloaded
    }

    static List<LangPackMap>? _langMapCache;
    static List<LangPackMap> getAllLanguagesWithNative(){
      final nativeList = <LangPackMap>[
        LangPackMap(langName: 'Magyar', langId: 'hu', langURL: '', langFlag: '🇭🇺'),
        LangPackMap(langName: 'English', langId: 'en', langURL: '', langFlag: '🇺🇸/🇬🇧')];

      if(!DataCache.getHasNetwork()){
        return nativeList;
      }
      return nativeList + (_langMapCache == null ? <LangPackMap>[].toList() : _langMapCache!);
    }

    static Future<List<LangPackMap>?> getAllLanguages()async{
      if(_langMapCache != null){
        return _langMapCache;
      }
      try {
        final url = Uri.parse('https://raw.githubusercontent.com/zoligamer/Neptun-Mobile-fork/refs/heads/main/Languages/supportedLanguages.json');
        final response = await http.get(url);

        if (response.statusCode != 200) {
          return null;
        }

        Map<String, dynamic> jsonMap = conv.json.decode(response.body);
        final allLangItems = jsonMap['languagesMap'] as List<dynamic>;
        final List<LangPackMap> langPacksRoot = [];
        for (var item in allLangItems){
          langPacksRoot.add(LangPackMap.fromMap(item));
        }
        _langMapCache = langPacksRoot;
        return langPacksRoot;
      } catch (e) {
        return null;
      }
    }
  }

  class LangPackMap{
    final String langName;
    final String langFlag;
    final String langId;
    final String langURL;

    const LangPackMap({required this.langName, required this.langId, required this.langURL, required this.langFlag});

    static LangPackMap fromMap(Map<String, dynamic> json){
      return LangPackMap(langName: json['langName'], langId: json['langId'], langURL: json['langURL'], langFlag: json['langFlag']);
    }
  }

  class Coloring{
    static List<ThemePackMap>? _themeMapCache;

    static List<ThemePackMap>? getAllThemesCache(){
      return _themeMapCache;
    }

    static Future<List<ThemePackMap>?> getAllThemes()async{
      if(_themeMapCache != null){
        return _themeMapCache;
      }
      try {
        final url = Uri.parse('https://raw.githubusercontent.com/zoligamer/Neptun-Mobile-fork/refs/heads/main/Themes/supportedThemes.json');
        final response = await http.get(url);

        if (response.statusCode != 200) {
          return null;
        }

        Map<String, dynamic> jsonMap = conv.json.decode(response.body);
        final allThemeItems = jsonMap['themesMap'] as List<dynamic>;
        final List<ThemePackMap> themePacksRoot = [];
        for (var item in allThemeItems){
          themePacksRoot.add(ThemePackMap.fromMap(item));
        }
        _themeMapCache = themePacksRoot;
        return themePacksRoot;
      } catch (e) {
        return null;
      }
    }

    static Future<AppPalette?> getThemePackById(List<ThemePackMap>? themes, String neededID)async{
      if(themes == null){
        return null;
      }
      String? themeUrl;
      for(var item in themes){
        if(item.themeName == neededID){
          themeUrl = item.themeUrl;
          break;
        }
      }
      if(themeUrl == null){
        return null;
      }

      final url = Uri.parse(themeUrl);
      final response = await http.get(url);
      if (response.statusCode != 200) {
        return null;
      }
      return AppPalette.fromJson(response.body, (){}); // auto registers itself, as its downloaded, no need for the callback, def not invalid as it has just been downloaded
    }
  }

  class ThemePackMap{
    final String themeName;
    final String themeUrl;
    final Color themepackAccent;

    const ThemePackMap({required this.themeName, required this.themeUrl, required this.themepackAccent});

    static ThemePackMap fromMap(Map<String, dynamic> json){
      return ThemePackMap(themeName: json['themeName'], themeUrl: json['themeURL'], themepackAccent: Color(json['themeAccent']));
    }
  }

  class PetitionCounts {
    final int availableCount;
    final int startedCount;
    final int sentBackToCorrectionCount;
    final int submittedCount;

    const PetitionCounts({
      required this.availableCount,
      required this.startedCount,
      required this.sentBackToCorrectionCount,
      required this.submittedCount,
    });

    factory PetitionCounts.fromJson(Map<String, dynamic> json) {
      return PetitionCounts(
        availableCount: json['availableCount'] ?? 0,
        startedCount: json['startedCount'] ?? 0,
        sentBackToCorrectionCount: json['sentBackToCorrectionCount'] ?? 0,
        submittedCount: json['submittedCount'] ?? 0,
      );
    }
  }

  class PetitionTemplate {
    final String requestFormTemplateId;
    final String templateName;
    final String? validFrom;
    final String? validTo;
    final String? feeInformation;

    const PetitionTemplate({
      required this.requestFormTemplateId,
      required this.templateName,
      this.validFrom,
      this.validTo,
      this.feeInformation,
    });

    static String parseFeeInformation(dynamic fee) {
      if (fee == null) return '';
      if (fee is Map) {
        final feeVal = fee['feeValue'] ?? fee['fee'] ?? fee['amount'];
        final feeCurr = fee['feeCurrency'] ?? fee['currency'] ?? 'Ft';
        if (feeVal != null) {
          final numVal = double.tryParse(feeVal.toString()) ?? 0;
          if (numVal <= 0) return 'Ingyenes';
          final formatted = numVal == numVal.toInt() ? numVal.toInt().toString() : numVal.toStringAsFixed(0);
          final spaceFormatted = formatted.replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]} ');
          return 'Díj: $spaceFormatted ${feeCurr == 'HUF' ? 'Ft' : feeCurr}';
        }
      }
      final str = fee.toString().trim();
      if (str.isEmpty || str == 'null') return '';
      if (str.startsWith('{') && str.contains('feeValue')) {
        try {
          final feeMatch = RegExp(r'feeValue:\s*([0-9\.]+)').firstMatch(str) ?? RegExp(r'"feeValue":\s*([0-9\.]+)').firstMatch(str);
          final currMatch = RegExp(r'feeCurrency:\s*([A-Za-z]+)').firstMatch(str) ?? RegExp(r'"feeCurrency":\s*"([^"]+)"').firstMatch(str);
          if (feeMatch != null) {
            final numVal = double.tryParse(feeMatch.group(1) ?? '0') ?? 0;
            if (numVal <= 0) return 'Ingyenes';
            final curr = currMatch?.group(1) ?? 'Ft';
            final formatted = numVal == numVal.toInt() ? numVal.toInt().toString() : numVal.toStringAsFixed(0);
            final spaceFormatted = formatted.replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]} ');
            return 'Díj: $spaceFormatted ${curr == 'HUF' ? 'Ft' : curr}';
          }
        } catch (_) {}
      }
      return str;
    }

    factory PetitionTemplate.fromJson(Map<String, dynamic> json) {
      return PetitionTemplate(
        requestFormTemplateId: json['requestFormTemplateId']?.toString() ?? '',
        templateName: json['templateName']?.toString() ?? '',
        validFrom: json['validFrom']?.toString(),
        validTo: json['validTo']?.toString(),
        feeInformation: parseFeeInformation(json['feeInformation']),
      );
    }

    Map<String, dynamic> toJson() {
      return {
        'requestFormTemplateId': requestFormTemplateId,
        'templateName': templateName,
        'validFrom': validFrom,
        'validTo': validTo,
        'feeInformation': feeInformation,
      };
    }
  }

  class StartedPetition {
    final String requestFormTemplateId;
    final String templateName;
    final String? lastModified;
    final String? validFrom;
    final String? validTo;
    final String? feeInformation;
    final String? requestFormId;

    const StartedPetition({
      required this.requestFormTemplateId,
      required this.templateName,
      this.lastModified,
      this.validFrom,
      this.validTo,
      this.feeInformation,
      this.requestFormId,
    });

    factory StartedPetition.fromJson(Map<String, dynamic> json) {
      return StartedPetition(
        requestFormTemplateId: json['requestFormTemplateId']?.toString() ?? '',
        templateName: json['templateName']?.toString() ?? '',
        lastModified: json['lastModified']?.toString(),
        validFrom: json['validFrom']?.toString(),
        validTo: json['validTo']?.toString(),
        feeInformation: PetitionTemplate.parseFeeInformation(json['feeInformation']),
        requestFormId: json['requestFormId']?.toString(),
      );
    }

    Map<String, dynamic> toJson() {
      return {
        'requestFormTemplateId': requestFormTemplateId,
        'templateName': templateName,
        'lastModified': lastModified,
        'validFrom': validFrom,
        'validTo': validTo,
        'feeInformation': feeInformation,
        'requestFormId': requestFormId,
      };
    }
  }

  class SubmittedPetition {
    final String requestFormId;
    final String templateName;
    final String? submissionDate;
    final String requestFormIdentifier;
    final bool sentBackToCorrection;
    final String statusText;
    final int statusType;

    const SubmittedPetition({
      required this.requestFormId,
      required this.templateName,
      this.submissionDate,
      required this.requestFormIdentifier,
      this.sentBackToCorrection = false,
      this.statusText = '',
      this.statusType = 0,
    });

    factory SubmittedPetition.fromJson(Map<String, dynamic> json) {
      String status = '';
      int type = 0;
      if (json['uiDisplayState'] != null && json['uiDisplayState'] is Map) {
        final ui = json['uiDisplayState'];
        type = ui['type'] ?? 0;
        if (ui['reasons'] != null && ui['reasons'] is List && (ui['reasons'] as List).isNotEmpty) {
          status = (ui['reasons'] as List).join(', ');
        }
      }
      if (status.isEmpty) {
        status = json['statusText']?.toString() ?? '';
      }

      return SubmittedPetition(
        requestFormId: json['requestFormId']?.toString() ?? '',
        templateName: json['templateName']?.toString() ?? '',
        submissionDate: json['submissionDate']?.toString(),
        requestFormIdentifier: json['requestFormIdentifier']?.toString() ?? '',
        sentBackToCorrection: json['sentBackToCorrection'] == true,
        statusText: status,
        statusType: type,
      );
    }

    Map<String, dynamic> toJson() {
      return {
        'requestFormId': requestFormId,
        'templateName': templateName,
        'submissionDate': submissionDate,
        'requestFormIdentifier': requestFormIdentifier,
        'sentBackToCorrection': sentBackToCorrection,
        'statusText': statusText,
        'statusType': statusType,
      };
    }
  }

  class PetitionsRequest {
    static String getModernApiBase() {
      String url = storage.DataCache.getInstituteUrl() ?? '';
      url = url.replaceAll(RegExp(r'/MobileService\.svc.*$', caseSensitive: false), '');
      url = url.replaceAll(RegExp(r'/hallgato/?$', caseSensitive: false), '');
      url = url.replaceAll(RegExp(r'/ujhallgato/?$', caseSensitive: false), '');
      return '$url/ujhallgato';
    }

    static Future<PetitionCounts?> getPetitionCounts() async {
      try {
        final baseUrl = getModernApiBase();
        final url = Uri.parse('$baseUrl${URLs.PETITIONS_COUNT_URL}');
        final responseBody = await _APIRequest.getRequest(url, bearerToken: storage.DataCache.getAccessToken() ?? '');
        final decoded = conv.jsonDecode(responseBody);
        if (decoded['data'] != null) {
          return PetitionCounts.fromJson(decoded['data']);
        }
      } catch (e) {
        debug.log('Error fetching petition counts: $e');
      }
      return null;
    }

    static Future<List<PetitionTemplate>> getAvailableTemplates({int firstRow = 0, int lastRow = 100}) async {
      try {
        final baseUrl = getModernApiBase();
        final url = Uri.parse('$baseUrl${URLs.PETITIONS_TEMPLATES_URL}?sortAndPage.firstRow=$firstRow&sortAndPage.lastRow=$lastRow&sortAndPage.templateName=asc');
        final responseBody = await _APIRequest.getRequest(url, bearerToken: storage.DataCache.getAccessToken() ?? '');
        final decoded = conv.jsonDecode(responseBody);
        if (decoded['data'] != null && decoded['data'] is List) {
          final list = (decoded['data'] as List).map((item) => PetitionTemplate.fromJson(item)).toList();
          return list;
        }
      } catch (e) {
        debug.log('Error fetching petition templates: $e');
      }
      return [];
    }

    static Future<List<SubmittedPetition>> getSubmittedPetitions({int firstRow = 0, int lastRow = 100}) async {
      try {
        final baseUrl = getModernApiBase();
        final url = Uri.parse('$baseUrl${URLs.PETITIONS_SUBMITTED_URL}?sortAndPage.firstRow=$firstRow&sortAndPage.lastRow=$lastRow&sortAndPage.submissionDate=desc');
        final responseBody = await _APIRequest.getRequest(url, bearerToken: storage.DataCache.getAccessToken() ?? '');
        final decoded = conv.jsonDecode(responseBody);
        if (decoded['data'] != null && decoded['data'] is List) {
          final list = (decoded['data'] as List).map((item) => SubmittedPetition.fromJson(item)).toList();
          return list;
        }
      } catch (e) {
        debug.log('Error fetching submitted petitions: $e');
      }
      return [];
    }

    static Future<Map<String, dynamic>?> getStudentRequestForm(String templateId) async {
      try {
        final baseUrl = getModernApiBase();
        final url = Uri.parse('$baseUrl${URLs.PETITIONS_GET_FORM_URL}?requestFormTemplateId=$templateId');
        final responseBody = await _APIRequest.getRequest(url, bearerToken: storage.DataCache.getAccessToken() ?? '');
        final decoded = conv.jsonDecode(responseBody);
        if (decoded['data'] != null) {
          return decoded['data'] as Map<String, dynamic>;
        }
      } catch (e) {
        debug.log('Error fetching student request form: $e');
      }
      return null;
    }

    static Future<bool> savePageAndStepNext(List<Map<String, String>> formData) async {
      try {
        final baseUrl = getModernApiBase();
        final url = Uri.parse('$baseUrl${URLs.PETITIONS_SAVE_PAGE_URL}');
        final body = conv.jsonEncode({'formData': formData});
        final responseBody = await _APIRequest.postRequestWithRetry(url, body);
        final decoded = conv.jsonDecode(responseBody);
        return decoded['ErrorMessage'] == null;
      } catch (e) {
        debug.log('Error saving petition page: $e');
      }
      return false;
    }

    static Future<Map<String, dynamic>?> getCurrentPage() async {
      try {
        final baseUrl = getModernApiBase();
        final url = Uri.parse('$baseUrl${URLs.PETITIONS_CURRENT_PAGE_URL}');
        final responseBody = await _APIRequest.getRequest(url, bearerToken: storage.DataCache.getAccessToken() ?? '');
        final decoded = conv.jsonDecode(responseBody);
        if (decoded['data'] != null) {
          return decoded['data'] as Map<String, dynamic>;
        }
      } catch (e) {
        debug.log('Error fetching current page: $e');
      }
      return null;
    }

    static Future<String?> submitPetition() async {
      try {
        final baseUrl = getModernApiBase();
        final url = Uri.parse('$baseUrl${URLs.PETITIONS_SUBMIT_URL}');
        final responseBody = await _APIRequest.postRequestWithRetry(url, '{}');
        final decoded = conv.jsonDecode(responseBody);
        if (decoded['notification'] != null && decoded['notification'] is List && (decoded['notification'] as List).isNotEmpty) {
          return decoded['notification'][0]['description']?.toString();
        }
        return 'OK';
      } catch (e) {
        debug.log('Error submitting petition: $e');
      }
      return null;
    }

    static Future<List<StartedPetition>> getStartedPetitions({int firstRow = 0, int lastRow = 50}) async {
      try {
        final baseUrl = getModernApiBase();
        final url = Uri.parse('$baseUrl${URLs.PETITIONS_STARTED_TEMPLATES_URL}?sortAndPage.firstRow=$firstRow&sortAndPage.lastRow=$lastRow&sortAndPage.templateName=asc');
        final responseBody = await _APIRequest.getRequest(url, bearerToken: storage.DataCache.getAccessToken() ?? '');
        final decoded = conv.jsonDecode(responseBody);
        if (decoded['data'] != null && decoded['data'] is List) {
          final list = (decoded['data'] as List).map((item) => StartedPetition.fromJson(item)).toList();
          return list;
        }
      } catch (e) {
        debug.log('Error fetching started petitions: $e');
      }
      return [];
    }

    static Future<Map<String, dynamic>?> getStartedRequestFormTemplateDetails(String templateId) async {
      try {
        final baseUrl = getModernApiBase();
        final url = Uri.parse('$baseUrl${URLs.PETITIONS_STARTED_DETAILS_URL}?requestFormTemplateId=$templateId');
        final responseBody = await _APIRequest.getRequest(url, bearerToken: storage.DataCache.getAccessToken() ?? '');
        final decoded = conv.jsonDecode(responseBody);
        if (decoded['data'] != null && decoded['data'] is Map) {
          return decoded['data'] as Map<String, dynamic>;
        }
      } catch (e) {
        debug.log('Error fetching started template details: $e');
      }
      return null;
    }

    static Future<bool> invalidateRequestForm(String requestFormId) async {
      try {
        final baseUrl = getModernApiBase();
        final url = Uri.parse('$baseUrl${URLs.PETITIONS_INVALIDATE_URL}');
        final body = conv.jsonEncode({'requestFormId': requestFormId});
        final responseBody = await _APIRequest.postRequestWithRetry(url, body);
        final decoded = conv.jsonDecode(responseBody);
        return decoded['ErrorMessage'] == null;
      } catch (e) {
        debug.log('Error invalidating request form: $e');
      }
      return false;
    }

    static Future<bool> resetStartedPetition(String templateId, {String? requestFormId}) async {
      try {
        String? formId = requestFormId;
        if (formId == null || formId.isEmpty) {
          final details = await getStartedRequestFormTemplateDetails(templateId);
          formId = details?['requestFormId']?.toString();
        }
        if (formId != null && formId.isNotEmpty) {
          return await invalidateRequestForm(formId);
        }
      } catch (e) {
        debug.log('Error in resetStartedPetition: $e');
      }
      return false;
    }
  }

  // ==========================================
  // SZEMÉLYES ADATOK, PROFIL & DOKUMENTUMTÁR
  // ==========================================

  class GeneralUserData {
    final String title;
    final String firstName;
    final String lastName;
    final String bornName;
    final String bornDate;
    final String bornCountry;
    final String bornPlace;
    final String motherName;
    final String citizenship;
    final String sex;
    final String loginName;
    final String maritalStatus;
    final String educationalIdentifier;
    final String taxIdentifier;
    final String tajNumber;
    final int numberOfChildren;

    GeneralUserData({
      required this.title,
      required this.firstName,
      required this.lastName,
      required this.bornName,
      required this.bornDate,
      required this.bornCountry,
      required this.bornPlace,
      required this.motherName,
      required this.citizenship,
      required this.sex,
      required this.loginName,
      required this.maritalStatus,
      required this.educationalIdentifier,
      required this.taxIdentifier,
      required this.tajNumber,
      required this.numberOfChildren,
    });

    factory GeneralUserData.fromJson(Map<String, dynamic> json) {
      String cit = '';
      if (json['userCitizenship'] != null && json['userCitizenship'] is List && (json['userCitizenship'] as List).isNotEmpty) {
        cit = json['userCitizenship'][0]['citizenship']?.toString() ?? '';
      }
      return GeneralUserData(
        title: json['title']?.toString() ?? '',
        firstName: json['firstName']?.toString() ?? '',
        lastName: json['lastName']?.toString() ?? '',
        bornName: json['bornName']?.toString() ?? '${json['bornLastName'] ?? ''} ${json['bornFirstName'] ?? ''}'.trim(),
        bornDate: json['bornDate']?.toString() ?? '',
        bornCountry: json['bornCountry']?.toString() ?? '',
        bornPlace: json['bornPlace']?.toString() ?? '',
        motherName: json['motherName']?.toString() ?? '${json['motherLastName'] ?? ''} ${json['motherFirstName'] ?? ''}'.trim(),
        citizenship: cit.isNotEmpty ? cit : (json['bornCountry']?.toString() ?? 'Magyarország'),
        sex: json['sex']?.toString() ?? '',
        loginName: json['loginName']?.toString() ?? '',
        maritalStatus: json['maritalStatus']?.toString() ?? '',
        educationalIdentifier: json['educationalIdentifier']?.toString() ?? '',
        taxIdentifier: json['taxIdentifier']?.toString() ?? '',
        tajNumber: json['tajNumber']?.toString() ?? '',
        numberOfChildren: json['numberOfChildren'] is int ? json['numberOfChildren'] : 0,
      );
    }

    String get fullName => '$lastName $firstName'.trim();

    Map<String, dynamic> toJson() => {
      'title': title,
      'firstName': firstName,
      'lastName': lastName,
      'bornName': bornName,
      'bornDate': bornDate,
      'bornCountry': bornCountry,
      'bornPlace': bornPlace,
      'motherName': motherName,
      'citizenship': citizenship,
      'sex': sex,
      'loginName': loginName,
      'maritalStatus': maritalStatus,
      'educationalIdentifier': educationalIdentifier,
      'taxIdentifier': taxIdentifier,
      'tajNumber': tajNumber,
      'numberOfChildren': numberOfChildren,
    };
  }

  class StudentPersonalDocument {
    final String id;
    final String identifier;
    final String typeString;

    StudentPersonalDocument({required this.id, required this.identifier, required this.typeString});

    factory StudentPersonalDocument.fromJson(Map<String, dynamic> json) {
      return StudentPersonalDocument(
        id: json['id']?.toString() ?? '',
        identifier: json['identifier']?.toString() ?? '',
        typeString: json['typeString']?.toString() ?? '',
      );
    }

    Map<String, dynamic> toJson() => {
      'id': id,
      'identifier': identifier,
      'typeString': typeString,
    };
  }

  class StudentCardSticker {
    final String id;
    final String serialNumber;
    final String releaseDate;
    final String termString;
    final String statusString;

    StudentCardSticker({
      required this.id,
      required this.serialNumber,
      required this.releaseDate,
      required this.termString,
      required this.statusString,
    });

    factory StudentCardSticker.fromJson(Map<String, dynamic> json) {
      return StudentCardSticker(
        id: json['id']?.toString() ?? '',
        serialNumber: json['serialNumber']?.toString() ?? '',
        releaseDate: json['releaseDate']?.toString() ?? '',
        termString: json['termString']?.toString() ?? '',
        statusString: json['statusString']?.toString() ?? '',
      );
    }

    Map<String, dynamic> toJson() => {
      'id': id,
      'serialNumber': serialNumber,
      'releaseDate': releaseDate,
      'termString': termString,
      'statusString': statusString,
    };
  }

  class StudentCardDetails {
    final String id;
    final String serial;
    final String releaseDate;
    final String validityEnd;
    final String facultyString;
    final String statusString;
    final String primaryInstituteName;
    final List<StudentCardSticker> stickers;

    StudentCardDetails({
      required this.id,
      required this.serial,
      required this.releaseDate,
      required this.validityEnd,
      required this.facultyString,
      required this.statusString,
      required this.primaryInstituteName,
      required this.stickers,
    });

    factory StudentCardDetails.fromJson(Map<String, dynamic> json) {
      List<StudentCardSticker> stickerList = [];
      if (json['stickerInformation'] != null && json['stickerInformation'] is List) {
        stickerList = (json['stickerInformation'] as List)
            .map((s) => StudentCardSticker.fromJson(s))
            .toList();
      }
      return StudentCardDetails(
        id: json['id']?.toString() ?? '',
        serial: json['serial']?.toString() ?? '',
        releaseDate: json['releaseDate']?.toString() ?? '',
        validityEnd: json['validityEnd']?.toString() ?? '',
        facultyString: json['facultyString']?.toString() ?? '',
        statusString: json['statusString']?.toString() ?? '',
        primaryInstituteName: json['primaryInstituteName']?.toString() ?? '',
        stickers: stickerList,
      );
    }

    Map<String, dynamic> toJson() => {
      'id': id,
      'serial': serial,
      'releaseDate': releaseDate,
      'validityEnd': validityEnd,
      'facultyString': facultyString,
      'statusString': statusString,
      'primaryInstituteName': primaryInstituteName,
      'stickers': stickers.map((s) => s.toJson()).toList(),
    };
  }

  class StudentPhoneNumber {
    final String id;
    final String typeName;
    final String number;
    final bool isDefault;

    StudentPhoneNumber({required this.id, required this.typeName, required this.number, required this.isDefault});

    factory StudentPhoneNumber.fromJson(Map<String, dynamic> json) {
      return StudentPhoneNumber(
        id: json['phonenumberId']?.toString() ?? '',
        typeName: json['phonenumberTypeName']?.toString() ?? 'Mobil',
        number: json['phonenumber']?.toString() ?? '',
        isDefault: json['isDefault'] == true,
      );
    }

    Map<String, dynamic> toJson() => {
      'id': id,
      'typeName': typeName,
      'number': number,
      'isDefault': isDefault,
    };
  }

  class StudentAddress {
    final String id;
    final String typeName;
    final String postcode;
    final String city;
    final String street;

    StudentAddress({required this.id, required this.typeName, required this.postcode, required this.city, required this.street});

    factory StudentAddress.fromJson(Map<String, dynamic> json) {
      return StudentAddress(
        id: json['addressId']?.toString() ?? '',
        typeName: json['addressTypeName']?.toString() ?? 'Lakcím',
        postcode: json['postcode']?.toString() ?? '',
        city: json['city']?.toString() ?? '',
        street: json['street']?.toString() ?? '',
      );
    }

    String get fullAddress => '$postcode $city, $street'.trim();

    Map<String, dynamic> toJson() => {
      'id': id,
      'typeName': typeName,
      'postcode': postcode,
      'city': city,
      'street': street,
    };
  }

  class StudentEmail {
    final String id;
    final String typeName;
    final String email;
    final bool isDefault;

    StudentEmail({required this.id, required this.typeName, required this.email, required this.isDefault});

    factory StudentEmail.fromJson(Map<String, dynamic> json) {
      return StudentEmail(
        id: json['emailId']?.toString() ?? '',
        typeName: json['emailTypeName']?.toString() ?? 'Email',
        email: json['email']?.toString() ?? '',
        isDefault: json['isDefault'] == true,
      );
    }

    Map<String, dynamic> toJson() => {
      'id': id,
      'typeName': typeName,
      'email': email,
      'isDefault': isDefault,
    };
  }

  class StudentContacts {
    final List<StudentPhoneNumber> phones;
    final List<StudentAddress> addresses;
    final List<StudentEmail> emails;

    StudentContacts({required this.phones, required this.addresses, required this.emails});

    factory StudentContacts.fromJson(Map<String, dynamic> json) {
      final phoneList = (json['phonenumberList'] as List? ?? []).map((p) => StudentPhoneNumber.fromJson(p)).toList();
      final addressList = (json['addressList'] as List? ?? []).map((a) => StudentAddress.fromJson(a)).toList();
      final emailList = (json['emailList'] as List? ?? []).map((e) => StudentEmail.fromJson(e)).toList();
      return StudentContacts(phones: phoneList, addresses: addressList, emails: emailList);
    }

    Map<String, dynamic> toJson() => {
      'phonenumberList': phones.map((p) => p.toJson()).toList(),
      'addressList': addresses.map((a) => a.toJson()).toList(),
      'emailList': emails.map((e) => e.toJson()).toList(),
    };
  }

  class DefaultBankAccount {
    final String accountNumber;
    final String bankName;
    final String currency;
    final bool isDefault;

    DefaultBankAccount({
      required this.accountNumber,
      required this.bankName,
      required this.currency,
      required this.isDefault,
    });

    factory DefaultBankAccount.fromJson(Map<String, dynamic> json) {
      return DefaultBankAccount(
        accountNumber: json['accountNumber']?.toString() ?? json['bankAccountNumber']?.toString() ?? '',
        bankName: json['bankName']?.toString() ?? '',
        currency: json['currency']?.toString() ?? 'HUF',
        isDefault: json['isDefault'] == true,
      );
    }

    Map<String, dynamic> toJson() => {
      'accountNumber': accountNumber,
      'bankName': bankName,
      'currency': currency,
      'isDefault': isDefault,
    };
  }

  class UserProfileSettings {
    final bool isLoginNameVisible;
    final bool isNicknameVisible;
    final String loginName;
    final String nickname;
    final String photoLastChangedAt;

    UserProfileSettings({
      required this.isLoginNameVisible,
      required this.isNicknameVisible,
      required this.loginName,
      required this.nickname,
      required this.photoLastChangedAt,
    });

    factory UserProfileSettings.fromJson(Map<String, dynamic> json) {
      return UserProfileSettings(
        isLoginNameVisible: json['isLoginNameVisible'] == true,
        isNicknameVisible: json['isNicknameVisible'] == true,
        loginName: json['loginName']?.toString() ?? '',
        nickname: json['nickname']?.toString() ?? '',
        photoLastChangedAt: json['photoLastChangedAt']?.toString() ?? '',
      );
    }

    Map<String, dynamic> toJson() => {
      'isLoginNameVisible': isLoginNameVisible,
      'isNicknameVisible': isNicknameVisible,
      'loginName': loginName,
      'nickname': nickname,
      'photoLastChangedAt': photoLastChangedAt,
    };
  }

  class DocumentStorageDashboard {
    final int trDocumentsCount;
    final int documentsUploadedForStudentCount;
    final int documentsUploadedByStudentCount;
    final int trDocumentsThatShouldBeESignedCount;

    DocumentStorageDashboard({
      required this.trDocumentsCount,
      required this.documentsUploadedForStudentCount,
      required this.documentsUploadedByStudentCount,
      required this.trDocumentsThatShouldBeESignedCount,
    });

    factory DocumentStorageDashboard.fromJson(Map<String, dynamic> json) {
      return DocumentStorageDashboard(
        trDocumentsCount: json['trDocumentsCount'] is int ? json['trDocumentsCount'] : 0,
        documentsUploadedForStudentCount: json['documentsUploadedForStudentCount'] is int ? json['documentsUploadedForStudentCount'] : 0,
        documentsUploadedByStudentCount: json['documentsUploadedByStudentCount'] is int ? json['documentsUploadedByStudentCount'] : 0,
        trDocumentsThatShouldBeESignedCount: json['trDocumentsThatShouldBeESignedCount'] is int ? json['trDocumentsThatShouldBeESignedCount'] : 0,
      );
    }

    Map<String, dynamic> toJson() => {
      'trDocumentsCount': trDocumentsCount,
      'documentsUploadedForStudentCount': documentsUploadedForStudentCount,
      'documentsUploadedByStudentCount': documentsUploadedByStudentCount,
      'trDocumentsThatShouldBeESignedCount': trDocumentsThatShouldBeESignedCount,
    };
  }

  class StorageDocumentItem {
    final String id;
    final String name;
    final String type;
    final String uploadDate;
    final String? registrationNumber;
    final String? connectionType;
    final bool isDeletable;
    final String? certificationStatus;

    StorageDocumentItem({
      required this.id,
      required this.name,
      required this.type,
      required this.uploadDate,
      this.registrationNumber,
      this.connectionType,
      this.isDeletable = false,
      this.certificationStatus,
    });

    factory StorageDocumentItem.fromJson(Map<String, dynamic> json) {
      return StorageDocumentItem(
        id: json['id']?.toString() ?? json['documentationId']?.toString() ?? '',
        name: json['name']?.toString() ?? json['documentationName']?.toString() ?? '',
        type: json['type']?.toString() ?? json['documentationType']?.toString() ?? '',
        uploadDate: json['uploadDate']?.toString() ?? json['documentationUploadDate']?.toString() ?? '',
        registrationNumber: json['registrationNumber']?.toString(),
        connectionType: json['connectionType']?.toString(),
        isDeletable: json['isDeletable'] == true,
        certificationStatus: json['certificationStatusString']?.toString() ?? json['userCertificationStatusDescription']?.toString(),
      );
    }

    Map<String, dynamic> toJson() => {
      'id': id,
      'name': name,
      'type': type,
      'uploadDate': uploadDate,
      'registrationNumber': registrationNumber,
      'connectionType': connectionType,
      'isDeletable': isDeletable,
      'certificationStatus': certificationStatus,
    };
  }

  class PersonalDataRequest {
    static Future<GeneralUserData?> getGeneralUserData() async {
      try {
        final baseUrl = PetitionsRequest.getModernApiBase();
        final url = Uri.parse('$baseUrl${URLs.PERSONAL_DATA_GENERAL_URL}');
        final response = await _APIRequest.getRequest(url, bearerToken: storage.DataCache.getAccessToken() ?? '');
        final decoded = conv.jsonDecode(response);
        if (decoded['data'] != null && decoded['data'] is Map<String, dynamic>) {
          await storage.DataCache.setCachedPersonalDataRaw(response);
          return GeneralUserData.fromJson(decoded['data']);
        }
      } catch (e) {
        debug.log('Error fetching GeneralUserData: $e');
      }
      return null;
    }

    static Future<List<StudentPersonalDocument>> getStudentPersonalDocuments() async {
      try {
        final baseUrl = PetitionsRequest.getModernApiBase();
        final url = Uri.parse('$baseUrl${URLs.PERSONAL_DATA_DOCUMENTS_URL}');
        final response = await _APIRequest.getRequest(url, bearerToken: storage.DataCache.getAccessToken() ?? '');
        final decoded = conv.jsonDecode(response);
        if (decoded['data'] != null && decoded['data']['studentPersonalDocuments'] != null) {
          await storage.DataCache.setCachedPersonalDocumentsRaw(response);
          return (decoded['data']['studentPersonalDocuments'] as List)
              .map((d) => StudentPersonalDocument.fromJson(d))
              .toList();
        }
      } catch (e) {
        debug.log('Error fetching PersonalDocuments: $e');
      }
      return [];
    }

    static Future<StudentCardDetails?> getStudentCardDetails(String cardId) async {
      try {
        final baseUrl = PetitionsRequest.getModernApiBase();
        final url = Uri.parse('$baseUrl${URLs.PERSONAL_DATA_CARD_DETAILS_URL}?id=$cardId');
        final response = await _APIRequest.getRequest(url, bearerToken: storage.DataCache.getAccessToken() ?? '');
        final decoded = conv.jsonDecode(response);
        if (decoded['data'] != null && decoded['data'] is Map<String, dynamic>) {
          await storage.DataCache.setCachedStudentCardRaw(response);
          return StudentCardDetails.fromJson(decoded['data']);
        }
      } catch (e) {
        debug.log('Error fetching StudentCardDetails: $e');
      }
      return null;
    }

    static Future<StudentContacts?> getStudentPersonalDataContacts() async {
      try {
        final baseUrl = PetitionsRequest.getModernApiBase();
        final url = Uri.parse('$baseUrl${URLs.PERSONAL_DATA_CONTACTS_URL}');
        final response = await _APIRequest.getRequest(url, bearerToken: storage.DataCache.getAccessToken() ?? '');
        final decoded = conv.jsonDecode(response);
        if (decoded['data'] != null && decoded['data'] is Map<String, dynamic>) {
          await storage.DataCache.setCachedPersonalContactsRaw(response);
          return StudentContacts.fromJson(decoded['data']);
        }
      } catch (e) {
        debug.log('Error fetching StudentContacts: $e');
      }
      return null;
    }

    static Future<DefaultBankAccount?> getDefaultBankAccount() async {
      try {
        final baseUrl = PetitionsRequest.getModernApiBase();
        final url = Uri.parse('$baseUrl${URLs.PERSONAL_DATA_BANK_ACCOUNT_URL}');
        final response = await _APIRequest.getRequest(url, bearerToken: storage.DataCache.getAccessToken() ?? '');
        final decoded = conv.jsonDecode(response);
        if (decoded['data'] != null && decoded['data'] is Map<String, dynamic>) {
          await storage.DataCache.setCachedBankAccountRaw(response);
          return DefaultBankAccount.fromJson(decoded['data']);
        }
      } catch (e) {
        debug.log('Error fetching DefaultBankAccount: $e');
      }
      return null;
    }
  }

  class UserProfileRequest {
    static Future<String?> getUserAvatar({bool forceRefresh = false}) async {
      if (!forceRefresh) {
        final cached = storage.DataCache.getCachedUserAvatarBase64();
        if (cached != null && cached.isNotEmpty) {
          return cached;
        }
      }
      try {
        final baseUrl = PetitionsRequest.getModernApiBase();
        final url = Uri.parse('$baseUrl${URLs.USER_PROFILE_AVATAR_URL}?imageSizeType=Normal');
        final response = await _APIRequest.getRequest(url, bearerToken: storage.DataCache.getAccessToken() ?? '');
        final decoded = conv.jsonDecode(response);
        if (decoded['data'] != null && decoded['data']['image'] != null) {
          final imgBase64 = decoded['data']['image'].toString();
          await storage.DataCache.setCachedUserAvatarBase64(imgBase64);
          return imgBase64;
        }
      } catch (e) {
        debug.log('Error fetching UserAvatar: $e');
      }
      return null;
    }

    static Future<UserProfileSettings?> getUserProfileSettings() async {
      try {
        final baseUrl = PetitionsRequest.getModernApiBase();
        final url = Uri.parse('$baseUrl${URLs.USER_PROFILE_SETTINGS_URL}');
        final response = await _APIRequest.getRequest(url, bearerToken: storage.DataCache.getAccessToken() ?? '');
        final decoded = conv.jsonDecode(response);
        if (decoded['data'] != null && decoded['data'] is Map<String, dynamic>) {
          await storage.DataCache.setCachedProfileSettingsRaw(response);
          return UserProfileSettings.fromJson(decoded['data']);
        }
      } catch (e) {
        debug.log('Error fetching UserProfileSettings: $e');
      }
      return null;
    }

    static Future<List<String>> getFallbackColorCodes() async {
      try {
        final baseUrl = PetitionsRequest.getModernApiBase();
        final url = Uri.parse('$baseUrl${URLs.USER_PROFILE_FALLBACK_COLORS_URL}');
        final response = await _APIRequest.getRequest(url, bearerToken: storage.DataCache.getAccessToken() ?? '');
        final decoded = conv.jsonDecode(response);
        if (decoded['data'] != null && decoded['data'] is List) {
          return (decoded['data'] as List).map((c) => c.toString()).toList();
        }
      } catch (e) {
        debug.log('Error fetching FallbackColorCodes: $e');
      }
      return ['A62C2C', 'F2994A', '00DEA4', '0943D9', 'BDD910', 'FF2113', 'B605BA'];
    }

    static Future<bool> isPasswordModificationAllowed() async {
      try {
        final baseUrl = PetitionsRequest.getModernApiBase();
        final url = Uri.parse('$baseUrl${URLs.USER_PROFILE_IS_PASSWORD_MOD_ALLOWED_URL}');
        final response = await _APIRequest.getRequest(url, bearerToken: storage.DataCache.getAccessToken() ?? '');
        final decoded = conv.jsonDecode(response);
        if (decoded['data'] != null) {
          return decoded['data'] == true;
        }
      } catch (e) {
        debug.log('Error fetching isPasswordModificationAllowed: $e');
      }
      return true;
    }

    static Future<bool> saveUserProfileSettings({
      required String loginName,
      required String nickname,
      int avatarType = 0,
      String? base64EncodedProfilePicture,
    }) async {
      try {
        final baseUrl = PetitionsRequest.getModernApiBase();
        final url = Uri.parse('$baseUrl${URLs.USER_PROFILE_SAVE_SETTINGS_URL}');
        final body = conv.jsonEncode({
          'loginName': loginName,
          'nickname': nickname,
          'avatarType': avatarType,
          'base64EncodedProfilePicture': base64EncodedProfilePicture ?? '',
        });
        final response = await _APIRequest.postRequestWithRetry(url, body);
        final decoded = conv.jsonDecode(response);
        return decoded['errorMessage'] == null && decoded['ErrorMessage'] == null;
      } catch (e) {
        debug.log('Error saving UserProfileSettings: $e');
      }
      return false;
    }
  }

  class DocumentStorageRequest {
    static Future<DocumentStorageDashboard?> getDashboardData() async {
      try {
        final baseUrl = PetitionsRequest.getModernApiBase();
        final url = Uri.parse('$baseUrl${URLs.DOCUMENT_STORAGE_DASHBOARD_URL}');
        final response = await _APIRequest.getRequest(url, bearerToken: storage.DataCache.getAccessToken() ?? '');
        final decoded = conv.jsonDecode(response);
        if (decoded['data'] != null && decoded['data'] is Map<String, dynamic>) {
          await storage.DataCache.setCachedStorageDashboardRaw(response);
          return DocumentStorageDashboard.fromJson(decoded['data']);
        }
      } catch (e) {
        debug.log('Error fetching DocumentStorageDashboard: $e');
      }
      return null;
    }

    static Future<List<StorageDocumentItem>> getDocumentsUploadedForStudent({int firstRow = 0, int lastRow = 50}) async {
      try {
        final baseUrl = PetitionsRequest.getModernApiBase();
        final url = Uri.parse('$baseUrl${URLs.DOCUMENT_STORAGE_FOR_STUDENT_URL}?sortAndPage.firstRow=$firstRow&sortAndPage.lastRow=$lastRow');
        final response = await _APIRequest.getRequest(url, bearerToken: storage.DataCache.getAccessToken() ?? '');
        final decoded = conv.jsonDecode(response);
        if (decoded['data'] != null && decoded['data'] is List) {
          final list = (decoded['data'] as List).map((d) => StorageDocumentItem.fromJson(d)).toList();
          await storage.DataCache.setCachedStorageForStudentDocsRaw(
              list.map((item) => conv.jsonEncode(item.toJson())).toList());
          return list;
        }
      } catch (e) {
        debug.log('Error fetching DocumentsUploadedForStudent: $e');
      }
      return [];
    }

    static Future<List<StorageDocumentItem>> getDocumentsUploadedByStudent({int firstRow = 0, int lastRow = 50}) async {
      try {
        final baseUrl = PetitionsRequest.getModernApiBase();
        final url = Uri.parse('$baseUrl${URLs.DOCUMENT_STORAGE_BY_STUDENT_URL}?sortAndPage.firstRow=$firstRow&sortAndPage.lastRow=$lastRow&sortAndPage.documentationName=asc');
        final response = await _APIRequest.getRequest(url, bearerToken: storage.DataCache.getAccessToken() ?? '');
        final decoded = conv.jsonDecode(response);
        if (decoded['data'] != null && decoded['data'] is List) {
          final list = (decoded['data'] as List).map((d) => StorageDocumentItem.fromJson(d)).toList();
          await storage.DataCache.setCachedStorageByStudentDocsRaw(
              list.map((item) => conv.jsonEncode(item.toJson())).toList());
          return list;
        }
      } catch (e) {
        debug.log('Error fetching DocumentsUploadedByStudent: $e');
      }
      return [];
    }

    static Future<List<StorageDocumentItem>> getTrDocuments({int firstRow = 0, int lastRow = 50}) async {
      try {
        final baseUrl = PetitionsRequest.getModernApiBase();
        final url = Uri.parse('$baseUrl${URLs.DOCUMENT_STORAGE_TR_URL}?request.isOnlyCertificated=false&request.mustBeCertified=false&request.isOnlyLegalRemediableFilter=false&sortAndPage.firstRow=$firstRow&sortAndPage.lastRow=$lastRow&sortAndPage.documentationName=asc');
        final response = await _APIRequest.getRequest(url, bearerToken: storage.DataCache.getAccessToken() ?? '');
        final decoded = conv.jsonDecode(response);
        if (decoded['data'] != null && decoded['data'] is List) {
          final list = (decoded['data'] as List).map((d) => StorageDocumentItem.fromJson(d)).toList();
          await storage.DataCache.setCachedStorageTrDocsRaw(
              list.map((item) => conv.jsonEncode(item.toJson())).toList());
          return list;
        }
      } catch (e) {
        debug.log('Error fetching TrDocuments: $e');
      }
      return [];
    }

    static Future<Uint8List?> downloadDocumentPdf(String docId) async {
      try {
        final baseUrl = PetitionsRequest.getModernApiBase();
        final url = Uri.parse('$baseUrl${URLs.DOCUMENT_STORAGE_DOWNLOAD_URL}');
        final body = conv.jsonEncode({
          'documentationIds': [docId]
        });
        final response = await _APIRequest.postRequestRawWithRetry(url, body);
        if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
          return response.bodyBytes;
        }
      } catch (e) {
        debug.log('Error downloading document PDF: $e');
      }
      return null;
    }
  }

  class NeptunCerts extends HttpOverrides {
    static NeptunCerts? _instance;
    static bool hasValidCertificate = true;

    static NeptunCerts getCerts(){
      if(_instance != null){
        return _instance!;
      }
      return NeptunCerts();
    }

    NeptunCerts(){
      _instance = this;
    }
    @override
    HttpClient createHttpClient(SecurityContext? context) {
      return super.createHttpClient(context)
        ..badCertificateCallback = (X509Certificate cert, String host, int port) {
          return true;
        };
    }
  }