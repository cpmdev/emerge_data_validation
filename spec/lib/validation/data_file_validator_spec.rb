require 'spec_helper'
require 'validation/data_file_validator'

describe EMERGE::Phenotype::DataFileValidator do
  VARIABLES = {
    "SUBJID" => {:values => nil, :row => 1, :original_name => "SUBJID", :normalized_type => :string},
    "DIAGNOSIS" => {:values => nil, :row => 2, :original_name => "Diagnosis", :normalized_type => :string}
  }

  it "flags in error a file with only one row" do
    process_with_expected_error("SUBJID,Diagnosis\r\n", "No rows containing data could be found", VARIABLES)
  end

  it "flags in error a file with a blank column" do
    process_with_expected_error("SUBJID,
1,109.8
2,003.3", "The 2nd column has a blank header - please set the header and define it in the data dictionary.", VARIABLES)
  end

  it "flags in error a file where not all columns are used" do
    variables = VARIABLES.clone
    variables["NEW_COL"] = {:values => nil, :row => 3, :original_name => "New_Col", :normailzed_type => :string}
    process_with_expected_error("SUBJID,Diagnosis
1,109.8
2,003.3", "The variable 'NEW_COL' is defined in the data dictionary, but does not appear in the data file.", variables)
  end

  it "flags in warning columns that are not in the same order as the data dictionary" do
    process_with_expected_warning("Diagnosis,SUBJID\r\n1,109.8\r\n2,003.3",
      "The variable 'Diagnosis' (1st column) is the 2nd variable in the data dictionary.  It's recommended to have variables in the same order.",
      VARIABLES)
  end

  it "flags in error empty/blank fields in data rows" do
    process_with_expected_error("SUBJID,Diagnosis\r\n1,  \r\n2,003.3",
      "A value for 'Diagnosis' (1st row) is blank, however it is best practice to provide a value to explicitly define missing data.",
      VARIABLES)
  end

  it "flags in error numeric fields out of range" do
    variables = VARIABLES.clone
    variables["DIAGNOSIS"][:normalized_type] = :integer
    variables["DIAGNOSIS"][:min_value] = 6
    variables["DIAGNOSIS"][:max_value] = 100
    process_with_expected_error("SUBJID,Diagnosis\r\n1,5",
      "The value for 'Diagnosis' (1st row) is outside of the range defined in the data dictionary (6 to 100).",
      variables)

    process_with_expected_success("SUBJID,Diagnosis\r\n1,10", variables)
  end

  it "flags in error integer fields that look like decimal values" do
    variables = VARIABLES.clone
    variables["DIAGNOSIS"][:normalized_type] = :integer
    variables["DIAGNOSIS"][:min_value] = 6
    variables["DIAGNOSIS"][:max_value] = 100
    process_with_expected_error("SUBJID,Diagnosis\r\n1,7.0",
      "The value for 'Diagnosis' in the 1st row (7.0) should be an integer, not a decimal.",
      variables)
  end

  def process_with_expected_warning data, expected_warning, variables
    validation = EMERGE::Phenotype::DataFileValidator.new(data, variables, :csv).validate
    puts validation[:errors] unless validation[:errors].length == 0
    validation[:errors].length.should == 0
    validation[:warnings].length.should be > 0
    result = validation[:warnings].include?(expected_warning)
    puts validation[:warnings] unless result
    result.should be_true
  end

  def process_with_expected_error data, expected_error, variables
    validation = EMERGE::Phenotype::DataFileValidator.new(data, variables, :csv).validate
    validation[:errors].length.should be > 0
    result = validation[:errors].include?(expected_error)
    puts validation[:errors] unless result
    result.should be_true
  end

  def process_with_expected_success data, variables
    validation = EMERGE::Phenotype::DataFileValidator.new(data, variables, :csv).validate
    puts validation[:errors] unless validation[:errors].blank?
    validation[:errors].length.should eql 0
    validation[:warnings].length.should eql 0
  end
end