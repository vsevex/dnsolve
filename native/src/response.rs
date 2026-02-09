use serde_json::{json, Value};

/// Builds a DNS response JSON object in the same schema as Google/Cloudflare
/// DoH JSON responses so the Dart side can parse it with existing `fromJson`.
pub struct ResponseBuilder {
    status: i32,
    tc: bool,
    rd: bool,
    ra: bool,
    ad: bool,
    cd: bool,
    questions: Vec<Value>,
    answers: Vec<Value>,
    comment: Option<String>,
}

impl ResponseBuilder {
    pub fn new() -> Self {
        Self {
            status: 0,
            tc: false,
            rd: true,
            ra: true,
            ad: false,
            cd: false,
            questions: Vec::new(),
            answers: Vec::new(),
            comment: None,
        }
    }

    pub fn status(mut self, status: i32) -> Self {
        self.status = status;
        self
    }

    pub fn rd(mut self, rd: bool) -> Self {
        self.rd = rd;
        self
    }

    pub fn ra(mut self, ra: bool) -> Self {
        self.ra = ra;
        self
    }

    pub fn ad(mut self, ad: bool) -> Self {
        self.ad = ad;
        self
    }

    pub fn comment(mut self, comment: String) -> Self {
        self.comment = Some(comment);
        self
    }

    pub fn add_question(mut self, name: &str, record_type: u16) -> Self {
        self.questions.push(json!({
            "name": name,
            "type": record_type as i64,
        }));
        self
    }

    pub fn add_answer(mut self, name: &str, record_type: u16, ttl: u32, data: &str) -> Self {
        self.answers.push(json!({
            "name": name,
            "type": record_type as i64,
            "TTL": ttl as i64,
            "data": data,
        }));
        self
    }

    pub fn build(self) -> Value {
        let mut response = json!({
            "Status": self.status,
            "TC": self.tc,
            "RD": self.rd,
            "RA": self.ra,
            "AD": self.ad,
            "CD": self.cd,
        });

        if !self.questions.is_empty() {
            response["Question"] = Value::Array(self.questions);
        }

        if !self.answers.is_empty() {
            response["Answer"] = Value::Array(self.answers);
        }

        if let Some(comment) = self.comment {
            response["comment"] = Value::String(comment);
        }

        response
    }

    /// Builds an error response with the given status code and message.
    pub fn error(status: i32, message: &str) -> Value {
        json!({
            "Status": status,
            "TC": false,
            "RD": true,
            "RA": true,
            "AD": false,
            "CD": false,
            "comment": message,
        })
    }
}
