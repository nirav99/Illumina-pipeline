public class Driver
{
	/**
	 * @param args
	 */
	public static void main(String[] args) 
	{
      InputParameters ip = new InputParameters(args);
      AddRGToBam rgAdder = new AddRGToBam(ip);
	}
}

