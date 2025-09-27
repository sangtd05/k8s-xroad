from flask import Flask, request, Response, jsonify
import subprocess, tempfile, os

app = Flask(__name__)

TSA_CONF = os.path.abspath("pki/tsa.conf")

@app.get("/api/v1/timestamp/certchain")
def chain():
    with open("pki/ca-chain.crt","rb") as f:
        data = f.read()
    return Response(data, mimetype="application/x-pem-file")

@app.post("/api/v1/timestamp")
def timestamp():
    if request.content_type != "application/timestamp-query":
        return jsonify({"error":"content-type must be application/timestamp-query"}), 400
    q = request.data
    with tempfile.NamedTemporaryFile(delete=False) as qf:
        qf.write(q)
        qf.flush()
        rsp_path = qf.name + ".tsr"
        try:
            subprocess.check_call([
                "openssl","ts","-reply",
                "-config",TSA_CONF,
                "-queryfile",qf.name,
                "-out",rsp_path
            ])
            with open(rsp_path,"rb") as rf:
                r = rf.read()
            return Response(r, mimetype="application/timestamp-reply")
        finally:
            try:
                os.remove(rsp_path)
            except FileNotFoundError:
                pass
            try:
                os.remove(qf.name)
            except FileNotFoundError:
                pass

if __name__ == "__main__":
    # waitress for production-like single binary if available, else Flask dev
    try:
        from waitress import serve
        serve(app, host="0.0.0.0", port=3000)
    except Exception:
        app.run(host="0.0.0.0", port=3000)
