IF OBJECT_ID('tempdb..#duvalAndNassauHSGrads') IS NOT NULL
	DROP TABLE #duvalAndNassauHSGrads
IF OBJECT_ID('tempdb..#hsGradsWithEthnicity') IS NOT NULL
	DROP TABLE #hsGradsWithEthnicity
IF OBJECT_ID('tempdb..#highschools') IS NOT NULL
	DROP TABLE #highschools
IF OBJECT_ID('tempdb..#devedeligibility') IS NOT NULL
	DROP TABLE #devedeligibility
IF OBJECT_ID('tempdb..#devedexempted') IS NOT NULL
	DROP TABLE #devedexempted
IF OBJECT_ID('tempdb..#pelleligibility') IS NOT NULL
	DROP TABLE #pelleligibility	
IF OBJECT_ID('tempdb..#prevSSNs') IS NOT NULL
	DROP TABLE #prevSSNs
IF OBJECT_ID('tempdb..#duals') IS NOT NULL
	DROP TABLE #duals
IF OBJECT_ID('tempdb..#degrank') IS NOT NULL
	DROP TABLE #degrank
IF OBJECT_ID('tempdb..#highestdegearned') IS NOT NULL
	DROP TABLE #highestdegearned
		

		
SELECT DISTINCT
	gen.FIELD_VALUE AS AWD_TYPE
	,CAST(gen2.FIELD_VALUE AS INT) AS DEGRANK
INTO
	#degrank
FROM
	MIS.dbo.UTL_CODE_TABLE_120 code
	INNER JOIN MIS.dbo.UTL_CODE_TABLE_GENERIC_120 gen ON gen.ISN_UTL_CODE_TABLE = code.ISN_UTL_CODE_TABLE
	INNER JOIN MIS.dbo.ST_PROGRAMS_A_136 prog ON prog.AWD_TY = gen.FIELD_VALUE
	INNER JOIN MIS.dbo.UTL_CODE_TABLE_GENERIC_120 gen2 ON gen2.ISN_UTL_CODE_TABLE = code.ISN_UTL_CODE_TABLE
WHERE
	code.TABLE_NAME = 'AWARD-LVL'
	AND code.STATUS = 'A'
	AND gen.cnxarraycolumn = 0
	AND gen2.cnxarraycolumn = 7
	AND prog.EFF_TRM_D <> ''
	AND prog.END_TRM = ''

SELECT
	cred.STDNT_ID
	,MAX(inst.INST_ID) AS [instID]
INTO
	#highschools
FROM
	MIS.dbo.ST_EXTRNL_CRDNTL_A_141 cred
	INNER JOIN MIS.dbo.ST_INSTITUTION_A_166 inst ON inst.INST_ID = cred.INST_ID
	INNER JOIN MIS.dbo.ST_STDNT_A_125 stdnt ON stdnt.STUDENT_SSN = cred.STDNT_ID
WHERE
	cred.CRDNTL_CD = 'HC'
	AND LEFT(inst.FLA_STATE_HS_CODE, 2) IN ('16','45')
	AND SUBSTRING(cred.ACT_GRAD_DT, 5, 2) IN ('05','06')
	AND inst.PUBLIC_PRIVATE_IND = 'S'
	AND LEFT(cred.ACT_GRAD_DT, 4) IN ('2014','2013','2015','2016')
GROUP BY
	cred.STDNT_ID

SELECT
	cred.STDNT_ID
	,inst.FLA_STATE_HS_CODE
	,inst.INST_NM
	,cred.ACT_GRAD_DT
	,cred.DIPL_TYPE
	,stdnt.SEX
	,stdnt.ETHNICITY
	,stdnt.ISN_ST_STDNT_A
INTO
	#duvalAndNassauHSGrads
FROM
	#highschools h
	INNER JOIN MIS.dbo.ST_EXTRNL_CRDNTL_A_141 cred ON cred.INST_ID = h.instID
												   AND cred.STDNT_ID = h.STDNT_ID
	INNER JOIN MIS.dbo.ST_INSTITUTION_A_166 inst ON inst.INST_ID = cred.INST_ID
	INNER JOIN MIS.dbo.ST_STDNT_A_125 stdnt ON stdnt.STUDENT_SSN = cred.STDNT_ID
WHERE
	cred.CRDNTL_CD = 'HC'
	AND LEFT(inst.FLA_STATE_HS_CODE, 2) IN ('16','45')
	AND SUBSTRING(cred.ACT_GRAD_DT, 5, 2) IN ('05','06')
	AND inst.PUBLIC_PRIVATE_IND = 'S'
	AND LEFT(cred.ACT_GRAD_DT, 4) IN ('2014','2013','2015','2016')


SELECT
	hsgrads.ISN_ST_STDNT_A
	,hsgrads.STDNT_ID
	,hsgrads.FLA_STATE_HS_CODE
	,hsgrads.INST_NM
	,hsgrads.ACT_GRAD_DT
	,hsgrads.DIPL_TYPE
	,hsgrads.SEX
	,CASE
		WHEN hsgrads.ETHNICITY = 'H' THEN 'H'
		WHEN [W] + [A] + [B] + [I] + [P] > 1 THEN 'M'
		WHEN [W] = 1 THEN 'W'
		WHEN [A] = 1 THEN 'A'
		WHEN [B] = 1 THEN 'B'
		WHEN [I] = 1 THEN 'I'
		WHEN [P] = 1 THEN 'P'
		ELSE 'X'
	END AS [Ethnicity]
INTO
	#hsGradsWithEthnicity
FROM
	#duvalAndNassauHSGrads hsgrads
	LEFT JOIN (SELECT ISN_ST_STDNT_A, RACE FROM MIS.dbo.ST_STDNT_A_RACE_125) race PIVOT (COUNT (RACE) FOR RACE IN ([W],[A],[B],[I],[X],[P])) AS racepivot ON racepivot.ISN_ST_STDNT_A = hsgrads.ISN_ST_STDNT_A

SELECT DISTINCT
	stdnt.*
	,ISNULL(CAST(CASE
		WHEN deved.[STUDENT-ID] IS NOT NULL THEN MAX(deved.[DE1050-HSCHOOL-DEV])
		WHEN MAX(deved2.[DE1050-HSCHOOL-DEV]) = '' THEN 'Pre-SB1720'
		ELSE MAX(deved2.[DE1050-HSCHOOL-DEV])
	END AS VARCHAR(MAX)), 'Pre-SB1720')  AS [Dev Ed Exemption Eligibility]
INTO
	#devedeligibility
FROM
	#hsGradsWithEthnicity stdnt
	LEFT JOIN MIS.dbo.ST_STDNT_A_PREV_STDNT_SSN_USED_125 prev ON prev.ISN_ST_STDNT_A = stdnt.ISN_ST_STDNT_A
	LEFT JOIN (SELECT
					r1.[STUDENT-ID]
					,r1.[DE1050-HSCHOOL-DEV]
					,ROW_NUMBER() OVER (PARTITION BY r1.[STUDENT-ID] ORDER BY xwalk.OrionTerm DESC) RN
				FROM
					StateSubmission.SDB.RecordType1 r1
					INNER JOIN MIS.dbo.vwTermYearXwalk xwalk ON xwalk.StateReportingTerm = r1.[TERM-ID]) deved ON deved.[STUDENT-ID] = stdnt.STDNT_ID
																											   AND deved.RN = 1
	LEFT JOIN (SELECT
					r1.[STUDENT-ID]
					,r1.[DE1050-HSCHOOL-DEV]
					,ROW_NUMBER() OVER (PARTITION BY r1.[STUDENT-ID] ORDER BY xwalk.OrionTerm DESC) RN
				FROM
					StateSubmission.SDB.RecordType1 r1
					INNER JOIN MIS.dbo.vwTermYearXwalk xwalk ON xwalk.StateReportingTerm = r1.[TERM-ID]) deved2 ON deved2.[STUDENT-ID] = prev.PREV_STDNT_SSN
																											   AND deved2.RN = 1
GROUP BY
	stdnt.ISN_ST_STDNT_A
	,stdnt.STDNT_ID
	,stdnt.FLA_STATE_HS_CODE
	,stdnt.INST_NM
	,stdnt.ACT_GRAD_DT
	,stdnt.DIPL_TYPE
	,stdnt.SEX
	,stdnt.Ethnicity
	,deved.[STUDENT-ID]

SELECT DISTINCT
	d.*
	,CASE
		WHEN demo.STATUS_IND IS NOT NULL THEN 'Exempted'
		ELSE 'Not Exempted'
	END AS [Dev Ed Exempted]
	,CAST(CAST(LEFT(d.ACT_GRAD_DT, 4) AS INT) + 1 AS VARCHAR) AS finAidYear
INTO
	#devedexempted
FROM
	#devedeligibility d
	LEFT JOIN MIS.dbo.ST_STDNT_TEST_DEMO_A_174 demo ON demo.STDNT_ID = d.STDNT_ID
													AND demo.PLACEMENT_AREA IN ('REA','MAT','ENG')
													AND demo.STATUS_IND IN ('F','Z')

SELECT DISTINCT
	t.*
	,CASE
		WHEN (t.finAidYear = '2017' AND isir17.ISN_WF_ISIR_1617 IS NULL) OR
			 (t.finAidYear = '2016' AND isir16.ISN_WF_ISIR_1516 IS NULL) OR
			 (t.finAidYear = '2015' AND isir15.ISN_WF_ISIR_1415 IS NULL) OR
			 (t.finAidYear = '2014' AND isir14.ISN_WF_ISIR_1314 IS NULL) THEN 'No FAFSA'
		WHEN (t.finAidYear = '2017' AND isir17.WF_IS_C_PELL_ELIG = 'Y') OR
			 (t.finAidYear = '2016' AND isir16.WF_IS_C_PELL_ELIG = 'Y') OR
			 (t.finAidYear = '2015' AND isir15.WF_IS_C_PELL_ELIG = 'Y') OR
			 (t.finAidYear = '2014' AND isir14.WF_IS_C_PELL_ELIG = 'Y') THEN 'Pell Eligible'
		WHEN (t.finAidYear = '2017' AND isir17.WF_IS_C_PELL_ELIG IS NULL) OR
			 (t.finAidYear = '2016' AND isir16.WF_IS_C_PELL_ELIG IS NULL) OR
			 (t.finAidYear = '2015' AND isir15.WF_IS_C_PELL_ELIG IS NULL) OR
			 (t.finAidYear = '2014' AND isir14.WF_IS_C_PELL_ELIG IS NULL) THEN 'Not Pell Eligible'
	END AS [Pell Eligible]
INTO
	#pelleligibility
FROM
	#devedexempted t
	LEFT JOIN MIS.dbo.WF_ISIR_1617_932 isir17 ON isir17.WF_IS_SSN = t.STDNT_ID
	LEFT JOIN MIS.dbo.WF_ISIR_1516_927 isir16 ON isir16.WF_IS_SSN = t.STDNT_ID
	LEFT JOIN MIS.dbo.WF_ISIR_1415_922 isir15 ON isir15.WF_IS_SSN = t.STDNT_ID
	LEFT JOIN MIS.dbo.WF_ISIR_1314_917 isir14 ON isir14.WF_IS_SSN = t.STDNT_ID
	LEFT JOIN MIS.dbo.WF_ISIR_1213_911 isir13 ON isir13.WF_IS_SSN = t.STDNT_ID


SELECT
	pell.*, ssn1.PREV_STDNT_SSN AS [prevSSN1], ssn2.PREV_STDNT_SSN AS [prevSSN2], ssn3.PREV_STDNT_SSN AS [prevSSN3], ssn4.PREV_STDNT_SSN AS [prevSSN4]
INTO
	#prevSSNs
FROM
	#pelleligibility pell
	LEFT JOIN MIS.dbo.ST_STDNT_A_PREV_STDNT_SSN_USED_125 ssn1 ON ssn1.ISN_ST_STDNT_A = pell.ISN_ST_STDNT_A
															  AND ssn1.cnxarraycolumn = 0
	LEFT JOIN MIS.dbo.ST_STDNT_A_PREV_STDNT_SSN_USED_125 ssn2 ON ssn2.ISN_ST_STDNT_A = pell.ISN_ST_STDNT_A
															  AND ssn2.cnxarraycolumn = 1
	LEFT JOIN MIS.dbo.ST_STDNT_A_PREV_STDNT_SSN_USED_125 ssn3 ON ssn3.ISN_ST_STDNT_A = pell.ISN_ST_STDNT_A
															  AND ssn3.cnxarraycolumn = 2
	LEFT JOIN MIS.dbo.ST_STDNT_A_PREV_STDNT_SSN_USED_125 ssn4 ON ssn4.ISN_ST_STDNT_A = pell.ISN_ST_STDNT_A
															  AND ssn4.cnxarraycolumn = 3

SELECT
	prev.*
	,ISNULL(MAX(dual.OrionTerm), 'Never') AS [Last Term Dual Enrolled]
	,ISNULL(MIN(nondual.OrionTerm), 'Never') AS [First Term At FSCJ]
	,ISNULL(MAX(nondual.OrionTerm), 'Never') AS [Last Term At FSCJ]
INTO
	#duals
FROM
	#prevSSNs prev
	LEFT JOIN (SELECT
					r6.*
					,xwalk.OrionTerm					
				FROM
					StateSubmission.SDB.RecordType6 r6
					INNER JOIN MIS.dbo.vwTermYearXwalk xwalk ON xwalk.StateReportingTerm = r6.DE1028
				WHERE
					r6.DE3004 <> 'NN') dual ON dual.DE1021 IN (prev.STDNT_ID, prev.prevSSN1, prev.prevSSN2, prev.prevSSN3, prev.prevSSN4)
	LEFT JOIN (SELECT
					r6.*
					,xwalk.OrionTerm					
				FROM
					StateSubmission.SDB.RecordType6 r6
					INNER JOIN MIS.dbo.vwTermYearXwalk xwalk ON xwalk.StateReportingTerm = r6.DE1028
				WHERE
					r6.DE3004 = 'NN') nondual ON nondual.DE1021 IN (prev.STDNT_ID, prev.prevSSN1, prev.prevSSN2, prev.prevSSN3, prev.prevSSN4)
GROUP BY
	prev.ISN_ST_STDNT_A
	,prev.ACT_GRAD_DT
	,prev.[Dev Ed Exempted]
	,prev.[Dev Ed Exemption Eligibility]
	,prev.DIPL_TYPE
	,prev.Ethnicity
	,prev.finAidYear
	,prev.FLA_STATE_HS_CODE
	,prev.INST_NM
	,prev.[Pell Eligible]
	,prev.STDNT_ID
	,prev.SEX
	,prev.prevSSN1
	,prev.prevSSN2
	,prev.prevSSN3
	,prev.prevSSN4

SELECT
	*
FROM
	#duals

SELECT
	 SRC.ISN_ST_STDNT_A
	,SRC.ACT_GRAD_DT
	,SRC.[Dev Ed Exempted]
	,SRC.[Dev Ed Exemption Eligibility]
	,SRC.DIPL_TYPE
	,SRC.Ethnicity
	,SRC.finAidYear
	,SRC.FLA_STATE_HS_CODE
	,SRC.INST_NM
	,SRC.[Pell Eligible]
	,SRC.STDNT_ID
	,SRC.SEX
	,SRC.prevSSN1
	,SRC.prevSSN2
	,SRC.prevSSN3
	,SRC.prevSSN4
	,SRC.[Last Term Dual Enrolled]
	,SRC.[First Term At FSCJ]
	,SRC.[Last Term At FSCJ]
	,SRC.AWD_TYPE AS [Highest Degree Earned]
INTO 
	#highestdegearned
FROM
	(
	SELECT
		d.*
		,deg.AWD_TYPE
		,ROW_NUMBER() OVER (PARTITION BY d.STDNT_ID ORDER BY deg.DEGRANK DESC) RN
	FROM
		#duals d
		LEFT JOIN MIS.dbo.ST_STDNT_OBJ_AWD_A_178 obj ON obj.STDNT_ID = d.STDNT_ID
													 AND obj.ACT_GRAD_TRM <> ''
		LEFT JOIN #degrank deg ON deg.AWD_TYPE = obj.AWD_TYPE) SRC
WHERE
	SRC.RN = 1


SELECT
	high.*
	,COUNT(obj.STDNT_ID) AS [Number of Awards]
INTO
	#numberAwards
FROM
	#highestdegearned high
	LEFT JOIN MIS.dbo.ST_STDNT_OBJ_AWD_A_178 obj ON obj.STDNT_ID = high.STDNT_ID
												 AND obj.ACT_GRAD_TRM <> ''
GROUP BY
	 high.ISN_ST_STDNT_A
	,high.ACT_GRAD_DT
	,high.[Dev Ed Exempted]
	,high.[Dev Ed Exemption Eligibility]
	,high.DIPL_TYPE
	,high.Ethnicity
	,high.finAidYear
	,high.FLA_STATE_HS_CODE
	,high.INST_NM
	,high.[Pell Eligible]
	,high.STDNT_ID
	,high.SEX
	,high.prevSSN1
	,high.prevSSN2
	,high.prevSSN3
	,high.prevSSN4
	,high.[Last Term Dual Enrolled]
	,high.[First Term At FSCJ]
	,high.[Last Term At FSCJ]
	,high.[Highest Degree Earned]

SELECT
	num.*
	,CASE
		WHEN (stdnt.CR_APPL_DT <> '' OR stdnt.VC_APPL_DT <> '' OR stdnt.BA_APPL_DT <> '' OR COUNT(obj.PGM_ID) > 0) AND num.[Last Term At FSCJ] = 'Never' THEN 'No Show'
	END AS [No Shows]
INTO
	#noshows
FROM
	#numberAwards num
	INNER JOIN MIS.dbo.ST_STDNT_A_125 stdnt ON stdnt.ISN_ST_STDNT_A = num.ISN_ST_STDNT_A
	LEFT JOIN MIS.dbo.ST_STDNT_OBJ_AWD_A_178 obj ON obj.STDNT_ID = num.STDNT_ID
												 AND obj.PGM_ID <> '3408'
												 AND obj.EFF_TERM >  num.[Last Term Dual Enrolled]
GROUP BY
	 num.ISN_ST_STDNT_A
	,num.ACT_GRAD_DT
	,num.[Dev Ed Exempted]
	,num.[Dev Ed Exemption Eligibility]
	,num.DIPL_TYPE
	,num.Ethnicity
	,num.finAidYear
	,num.FLA_STATE_HS_CODE
	,num.INST_NM
	,num.[Pell Eligible]
	,num.STDNT_ID
	,num.SEX
	,num.prevSSN1
	,num.prevSSN2
	,num.prevSSN3
	,num.prevSSN4
	,num.[Last Term Dual Enrolled]
	,num.[First Term At FSCJ]
	,num.[Last Term At FSCJ]
	,num.[Highest Degree Earned]
	,num.[Number of Awards]
	,stdnt.CR_APPL_DT
	,stdnt.VC_APPL_DT
	,stdnt.BA_APPL_DT
												
SELECT
	*
FROM 
	#noshows n
WHERE
	[Number of Awards] > 1