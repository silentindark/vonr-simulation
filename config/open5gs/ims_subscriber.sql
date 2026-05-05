-- IMS Subscriber Configuration for VoNR Demo
-- Run: docker exec -it mysql mysql -u root -pchangeme ims_hss_db < ims_subscriber.sql
-- NOTE: imsi column must equal MSISDN (pyHSS bug workaround)

INSERT INTO apn (apn_id, apn) VALUES (1, 'internet'), (3, 'ims')
  ON DUPLICATE KEY UPDATE apn=VALUES(apn);

-- UE1: MSISDN 9076543210
INSERT INTO auc (id, imsi, ki, opc, sqn, auth_scheme)
VALUES (1, '9076543210', '8baf473f2f8fd09487cccbd7097c6862',
        '8E27B6AF0E692E750F32667A3B14605D', 0, 'milenage')
  ON DUPLICATE KEY UPDATE ki=VALUES(ki);

INSERT INTO subscriber (id, imsi, msisdn, auc_id, default_apn, apn_list)
VALUES (1, '9076543210', '9076543210', 1, 1, '1,3')
  ON DUPLICATE KEY UPDATE msisdn=VALUES(msisdn);

INSERT INTO ims_subscriber (id, imsi, msisdn, scscf)
VALUES (1, '9076543210', '9076543210',
        'sip:scscf.ims.mnc001.mcc001.3gppnetwork.org:6060')
  ON DUPLICATE KEY UPDATE scscf=VALUES(scscf);

-- UE2: MSISDN 9076543211
INSERT INTO auc (id, imsi, ki, opc, sqn, auth_scheme)
VALUES (2, '9076543211', '8baf473f2f8fd09487cccbd7097c6862',
        '8E27B6AF0E692E750F32667A3B14605D', 0, 'milenage')
  ON DUPLICATE KEY UPDATE ki=VALUES(ki);

INSERT INTO subscriber (id, imsi, msisdn, auc_id, default_apn, apn_list)
VALUES (2, '9076543211', '9076543211', 2, 1, '1,3')
  ON DUPLICATE KEY UPDATE msisdn=VALUES(msisdn);

INSERT INTO ims_subscriber (id, imsi, msisdn, scscf)
VALUES (2, '9076543211', '9076543211',
        'sip:scscf.ims.mnc001.mcc001.3gppnetwork.org:6060')
  ON DUPLICATE KEY UPDATE scscf=VALUES(scscf);
