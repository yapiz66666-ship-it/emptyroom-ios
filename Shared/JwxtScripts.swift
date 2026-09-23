import Foundation

/// JavaScript run inside the logged-in WKWebView on the jwxt classroom page. Identical to the
/// Android JwglClassroomAutomation scripts: everything goes through the page's own JSON endpoints
/// with synchronous XHRs, so each call is one evaluateJavaScript round trip returning a JSON string.
enum JwxtScripts {
    private static let helpers = """
      const getText = url => {
        const request = new XMLHttpRequest();
        request.open('GET', url, false);
        request.send(null);
        if (request.status < 200 || request.status >= 300) {
          throw new Error('教务接口返回 ' + request.status + '，登录可能已失效');
        }
        return request.responseText;
      };
      const getJson = url => {
        const text = getText(url);
        try { return JSON.parse(text); } catch (e) { throw new Error('教务接口返回了非 JSON 内容，登录可能已失效'); }
      };
      const loadBuildings = campus => {
        if (!campus) return [];
        const result = getJson('/jsxsd/comm/getJxl?xqid=' + encodeURIComponent(campus));
        return (result.data || []).map(item => ({ value: item.jzwid, label: (item.jzwmc || '').trim() }));
      };
      const requireForm = () => {
        const term = document.getElementById('xnxq01id');
        const campus = document.getElementById('xqid');
        const mode = document.getElementById('kbjcmsid');
        if (!term || !campus) throw new Error('当前页面不是可识别的空教室查询页');
        return { term, campus, mode };
      };
      const fail = error => JSON.stringify({ error: String(error && error.message ? error.message : error) });
    """

    /// Page facts for PageDetector.
    static let detect = """
    (function() {
      try {
        const selects = Array.from(document.querySelectorAll('select')).map(s =>
          [s.id || '', s.name || '', Array.from(s.options || []).map(o => o.text || '').join(' ')].join(' '));
        const buttons = Array.from(document.querySelectorAll('button, input[type=button], input[type=submit]'))
          .map(b => b.innerText || b.value || '');
        return JSON.stringify({
          bodyText: document.body ? document.body.innerText.slice(0, 5000) : '',
          tableCount: document.querySelectorAll('table').length,
          selects, buttons
        });
      } catch (error) {
        return JSON.stringify({ bodyText: '', tableCount: 0, selects: [], buttons: [] });
      }
    })();
    """

    static let metadata = """
    (function() {
      \(helpers)
      try {
        const form = requireForm();
        const campuses = Array.from(form.campus.options || [])
          .filter(option => option.value)
          .map(option => ({ value: option.value, label: (option.text || '').trim() }));
        const selectedCampusValue = form.campus.value || (campuses[0] ? campuses[0].value : '');
        return JSON.stringify({
          academicTerm: form.term.value || '',
          campuses, selectedCampusValue,
          buildings: loadBuildings(selectedCampusValue)
        });
      } catch (error) { return fail(error); }
    })();
    """

    static func buildings(campus: String) -> String {
        """
        (function() {
          \(helpers)
          try { return JSON.stringify({ buildings: loadBuildings(\(quote(campus))) }); } catch (error) { return fail(error); }
        })();
        """
    }

    /// The building's whole-term class list plus the calendar facts needed to find the week.
    static func query(campus: String, building: String) -> String {
        """
        (function() {
          \(helpers)
          try {
            const form = requireForm();
            const term = form.term.value || '';
            let firstSaturday = '';
            let totalWeeks = 0;
            try {
              const calendar = new DOMParser().parseFromString(
                getText('/jsxsd/jxzl/jxzl_query?xnxq01id=' + encodeURIComponent(term)), 'text/html');
              const weekRows = Array.from(calendar.querySelectorAll('#dataTable tr'))
                .filter(row => /^第\\d+周$/.test((row.cells[0] && row.cells[0].innerText || '').trim()));
              totalWeeks = weekRows.length;
              if (weekRows.length && weekRows[0].cells[6]) firstSaturday = weekRows[0].cells[6].innerText.trim();
            } catch (calendarError) {
              console.warn('EmptyRoomAssistant calendar lookup failed', calendarError);
            }
            const params = new URLSearchParams({
              xnxq01id: term,
              kbjcmsid: form.mode ? form.mode.value : '',
              xqid: \(quote(campus)),
              jzwid: \(quote(building)),
              pageNum: '1',
              pageSize: '5000'
            });
            const data = getJson('/jsxsd/kbcx/kbxx_classroom_ifr?' + params.toString());
            if (data.code && data.code !== 0) throw new Error(data.msg || '教务接口查询失败');
            const rows = (data.data || []).map(row => ({
              jsmc: row.jsmc || '', kkzc: row.kkzc || '', zzdweek: row.zzdweek || '', jc: row.jc || '', sjbz: row.sjbz || ''
            }));
            if (data.count && rows.length < data.count) throw new Error('教务数据不完整：' + rows.length + '/' + data.count);
            return JSON.stringify({ academicTerm: term, firstSaturday, totalWeeks, rows });
          } catch (error) { return fail(error); }
        })();
        """
    }

    /// A JavaScript string literal for [text].
    static func quote(_ text: String) -> String {
        guard let data = try? JSONEncoder().encode(text), let literal = String(data: data, encoding: .utf8) else { return "''" }
        return literal
    }
}
